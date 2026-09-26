//! `logos-kit`: the Logos Kit wallet on the command line.
//!
//! Every command runs through the same engine and policy as the Basecamp
//! wallet, as the `LocalOwner` caller: a transaction is built, shown decoded
//! with its fee cap, confirmed on the terminal, and only then approved.
//!
//! Non-interactive use (demo scripts, E2E): set `LOGOS_KIT_PASSWORD`; only
//! then does `--yes` skip the confirmation.

use std::{
    io::{BufRead as _, IsTerminal as _, Write as _},
    path::PathBuf,
    time::Instant,
};

use anyhow::{Context as _, Result, bail, ensure};
use clap::{Parser, Subcommand};
use wallet_engine::{
    engine::{Config, Engine, Lifecycle, RequestView, TxStatus},
    policy::{Caller, code_of},
    session::{AccountKind, Birthday, DataDir, Session, Zone},
    tx::Intent,
    vault::KdfCost,
};

#[derive(Parser)]
#[command(name = "logos-kit", version, about = "Logos Kit wallet for LEZ")]
struct Cli {
    /// Wallet data directory.
    #[arg(long, global = true, env = "LOGOS_KIT_HOME")]
    data: Option<PathBuf>,
    /// Zone id: `lez-testnet`, `lez-local`, or one added with --sequencer.
    #[arg(
        long,
        global = true,
        env = "LOGOS_KIT_ZONE",
        default_value = "lez-testnet"
    )]
    zone: String,
    /// Sequencer URL, to add a zone that isn't built in.
    #[arg(long, global = true)]
    sequencer: Option<String>,
    /// Skip the confirmation (only with LOGOS_KIT_PASSWORD set).
    #[arg(long, global = true)]
    yes: bool,
    /// Print results as JSON.
    #[arg(long, global = true)]
    json: bool,
    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand)]
enum Command {
    /// Create a new wallet and show its recovery phrase once.
    Init,
    /// Restore a wallet from a recovery phrase (asked on the terminal).
    Restore {
        /// First used around this date (YYYY-MM-DD); earlier blocks are skipped.
        #[arg(long, conflicts_with = "from_genesis")]
        from_date: Option<String>,
        /// Scan the whole chain (slow, always complete).
        #[arg(long)]
        from_genesis: bool,
    },
    /// Accounts.
    #[command(subcommand)]
    Account(AccountCmd),
    /// Native balance of an account (public, or private as synced).
    Balance { account: String },
    /// Catch up with the chain.
    Sync,
    /// Send native tokens, public to public.
    Send {
        #[arg(long)]
        from: String,
        #[arg(long)]
        to: String,
        #[arg(long)]
        amount: u128,
    },
    /// Move native tokens from a public account into your private account (proves locally).
    Shield {
        #[arg(long)]
        from: String,
        #[arg(long)]
        to: String,
        #[arg(long)]
        amount: u128,
    },
    /// Zone, sync and network state.
    Status,
    /// Zones this wallet knows.
    Zones,
    /// Show the recovery phrase (asks for the password again).
    Reveal,
    /// Change the wallet password.
    Password,
    /// Lock after this many seconds without use (60–86400).
    AutoLock { seconds: u32 },
}

#[derive(Subcommand)]
enum AccountCmd {
    List,
    New {
        #[arg(long)]
        private: bool,
    },
    /// Name an account; without a name, clear it.
    Label {
        account: String,
        name: Option<String>,
    },
    /// Import a public account by private key (asked on the terminal).
    Import,
}

fn data_dir(cli: &Cli) -> Result<DataDir> {
    if let Some(dir) = &cli.data {
        return Ok(DataDir::new(dir));
    }
    let home = std::env::var_os("HOME").context("HOME is not set; pass --data")?;
    Ok(DataDir::new(PathBuf::from(home).join(".logos-kit")))
}

fn zone(cli: &Cli, data: &DataDir) -> Result<Zone> {
    if let Some(url) = &cli.sequencer {
        return Ok(Zone {
            id: cli.zone.clone(),
            chain: format!("lez:{}", cli.zone.trim_start_matches("lez-")),
            sequencer: url.clone(),
        });
    }
    for z in [Zone::testnet(), Zone::local()] {
        if z.id == cli.zone {
            return Ok(z);
        }
    }
    data.zones()?
        .into_iter()
        .find(|z| z.id == cli.zone)
        .with_context(|| format!("unknown zone {}; add it with --sequencer <url>", cli.zone))
}

fn noninteractive() -> Option<String> {
    std::env::var("LOGOS_KIT_PASSWORD").ok()
}

fn password(prompt: &str) -> Result<String> {
    match noninteractive() {
        Some(pw) => Ok(pw),
        None => Ok(rpassword::prompt_password(prompt)?),
    }
}

fn new_password() -> Result<String> {
    if let Some(pw) = noninteractive() {
        return Ok(pw);
    }
    let pw = rpassword::prompt_password("New password: ")?;
    ensure!(pw.chars().count() >= 8, "use at least 8 characters");
    ensure!(
        rpassword::prompt_password("Repeat it: ")? == pw,
        "the passwords don't match"
    );
    Ok(pw)
}

fn confirm(cli: &Cli, question: &str) -> Result<bool> {
    if cli.yes {
        ensure!(
            noninteractive().is_some(),
            "--yes only works non-interactively (LOGOS_KIT_PASSWORD set)"
        );
        return Ok(true);
    }
    ensure!(
        std::io::stdin().is_terminal(),
        "no terminal to confirm on; use --yes with LOGOS_KIT_PASSWORD for scripts"
    );
    print!("{question} [y/N] ");
    std::io::stdout().flush()?;
    let mut line = String::new();
    std::io::stdin().lock().read_line(&mut line)?;
    Ok(matches!(line.trim(), "y" | "Y" | "yes"))
}

/// YYYY-MM-DD (UTC midnight) → unix ms (days-from-civil, H. Hinnant).
fn date_ms(date: &str) -> Result<u64> {
    let parts: Vec<i64> = date
        .split('-')
        .map(str::parse)
        .collect::<Result<_, _>>()
        .context("date must be YYYY-MM-DD")?;
    let [y, m, d] = parts[..] else {
        bail!("date must be YYYY-MM-DD");
    };
    let leap = (y % 4 == 0 && y % 100 != 0) || y % 400 == 0;
    let days_in = [
        31,
        if leap { 29 } else { 28 },
        31,
        30,
        31,
        30,
        31,
        31,
        30,
        31,
        30,
        31,
    ];
    ensure!(
        (1..=12).contains(&m) && d >= 1 && d <= days_in[usize::try_from(m - 1)?],
        "no such date: {date}"
    );
    let y = if m <= 2 { y - 1 } else { y };
    let era = y.div_euclid(400);
    let yoe = y - era * 400;
    let mp = (m + 9) % 12;
    let doy = (153 * mp + 2) / 5 + d - 1;
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    let days = era * 146_097 + doe - 719_468;
    u64::try_from(days * 86_400_000).context("date before 1970")
}

fn print(cli: &Cli, value: &serde_json::Value, human: impl FnOnce()) {
    if cli.json {
        println!("{value}");
    } else {
        human();
    }
}

async fn open(cli: &Cli) -> Result<(Session, String)> {
    let data = data_dir(cli)?;
    ensure!(
        data.is_initialized(),
        "no wallet in {}; run `logos-kit init` or `logos-kit restore`",
        data.root().display()
    );
    let zone = zone(cli, &data)?;
    let pw = password("Password: ")?;
    Ok((Session::unlock(data, &pw, zone)?, pw))
}

fn describe(status: &TxStatus, started: Instant) -> String {
    let what = match status.lifecycle {
        Lifecycle::Building => "building",
        Lifecycle::Proving => "proving locally (about 5–6 min on a desktop CPU; keep this open)",
        Lifecycle::Signing => "signing",
        Lifecycle::Submitted => "submitted, waiting for a block",
        Lifecycle::Included => "included",
        Lifecycle::Dropped => "not sent",
        Lifecycle::Rejected => "declined",
        Lifecycle::Expired => "expired",
        Lifecycle::AwaitingApproval => "waiting for approval",
    };
    format!("[{:>4}s] {what}", started.elapsed().as_secs())
}

async fn transact(cli: &Cli, intent: Intent) -> Result<()> {
    // JSON output leaves no room for the review; scripts confirm with --yes.
    ensure!(
        !cli.json || cli.yes,
        "--json needs --yes (run without --json to review first)"
    );
    let (session, pw) = open(cli).await?;
    let engine = Engine::new(session, Config::default());
    let owner = Caller::LocalOwner;
    let ticket = engine.request_tx(&owner, None, intent).await?;
    let RequestView::Transaction(review) = &ticket.request else {
        bail!("unexpected request type");
    };
    if !cli.json {
        let i = &review.intent;
        let kind = if i.is_private() {
            "Shield (public → your private account)"
        } else {
            "Send"
        };
        println!("{kind} on {}", review.chain);
        println!(
            "  from    {}  (balance {})",
            i.from_account(),
            review.from_balance
        );
        println!("  to      {}", i.to_account());
        println!("  amount  {}", i.amount());
        match (&review.fee.max_fee, &review.fee.payer) {
            (Some(max), Some(payer)) => {
                println!("  fee     up to {max}, paid by {payer}");
                if let Some(base) = review.fee.base_fee_exec {
                    println!("          network base fee now {base} per gas");
                }
            }
            _ => println!("  fee     none (private transactions are fee-exempt)"),
        }
        println!("  request {}", review.request_hash);
    }
    if !confirm(cli, "Approve?")? {
        engine.reject(&owner, &ticket.handle)?;
        bail!("declined");
    }
    let started = Instant::now();
    let json = cli.json;
    let mut progress = move |s: &TxStatus| {
        if !json {
            println!("{}", describe(s, started));
        }
    };
    let approved = engine
        .approve(
            &owner,
            &ticket.handle,
            &review.request_hash,
            Some(&pw),
            &mut progress,
        )
        .await;
    let status = match approved {
        Ok(status) => status,
        Err(e) => {
            // Say how far it got: a submitted tx may still land; don't resend blindly.
            if let Ok(s) = engine.status(&owner, &ticket.handle)
                && let Some(hash) = &s.tx_hash
            {
                eprintln!("tx {hash} was submitted; check it before sending again");
            }
            return Err(e);
        }
    };
    if let Some(warning) = &status.error {
        eprintln!("note: {warning}");
    }
    print(cli, &serde_json::to_value(&status)?, || {
        println!(
            "tx {} in block {} (outcome: {:?})",
            status.tx_hash.as_deref().unwrap_or("?"),
            status.block.map_or("?".into(), |b| b.to_string()),
            status.outcome
        );
    });
    engine.lock().await
}

async fn run(cli: Cli) -> Result<()> {
    match &cli.command {
        Command::Init => {
            let data = data_dir(&cli)?;
            let zone = zone(&cli, &data)?;
            let pw = new_password()?;
            let (session, phrase) = Session::create(data, &pw, zone, KdfCost::DEFAULT)?;
            print(&cli, &serde_json::json!({ "created": true }), || {
                println!(
                    "Recovery phrase (write it down; it is shown once):\n\n  {}\n",
                    *phrase
                );
            });
            if cli.json {
                // Scripts need the phrase to test restore; humans saw it above.
                eprintln!("{}", *phrase);
            }
            session.lock()
        }
        Command::Restore {
            from_date,
            from_genesis,
        } => {
            let data = data_dir(&cli)?;
            let zone = zone(&cli, &data)?;
            let phrase = match std::env::var("LOGOS_KIT_PHRASE") {
                Ok(p) => p,
                Err(_) => rpassword::prompt_password("Recovery phrase: ")?,
            };
            let birthday = match (from_date, from_genesis) {
                (Some(d), _) => Birthday::At(date_ms(d)?),
                (None, true) => Birthday::Genesis,
                (None, false) => bail!(
                    "say when the wallet was first used: --from-date YYYY-MM-DD, or --from-genesis"
                ),
            };
            let pw = new_password()?;
            Session::restore(data, &pw, &phrase, birthday, zone, KdfCost::DEFAULT)?.lock()?;
            println!("Restored. Run `logos-kit sync` to find your accounts.");
            Ok(())
        }
        Command::Account(cmd) => {
            let (mut session, _) = open(&cli).await?;
            match cmd {
                AccountCmd::List => {
                    let accounts = session.accounts()?;
                    print(&cli, &serde_json::to_value(&accounts)?, || {
                        for a in &accounts {
                            println!(
                                "{:<8} {:<46} {:<8} {}",
                                format!("{:?}", a.kind).to_lowercase(),
                                a.account_id,
                                a.path.as_deref().unwrap_or("-"),
                                a.label.as_deref().unwrap_or("")
                            );
                        }
                    });
                }
                AccountCmd::New { private } => {
                    let kind = if *private {
                        AccountKind::Private
                    } else {
                        AccountKind::Public
                    };
                    let a = session.new_account(kind)?;
                    print(&cli, &serde_json::to_value(&a)?, || {
                        println!("{}", a.account_id);
                    });
                }
                AccountCmd::Label { account, name } => {
                    session.set_label(account, name.as_deref())?;
                }
                AccountCmd::Import => {
                    let key = match std::env::var("LOGOS_KIT_IMPORT_KEY") {
                        Ok(k) => k,
                        Err(_) => rpassword::prompt_password("Private key (hex): ")?,
                    };
                    let a = session.import_public_key(&key)?;
                    print(&cli, &serde_json::to_value(&a)?, || {
                        println!("{}", a.account_id);
                    });
                }
            }
            session.lock()
        }
        Command::Balance { account } => {
            let (mut session, _) = open(&cli).await?;
            let balance = session.balance(account).await?;
            print(
                &cli,
                &serde_json::json!({ "balance": balance.to_string() }),
                || {
                    println!("{balance}");
                },
            );
            session.lock()
        }
        Command::Sync => {
            let (mut session, _) = open(&cli).await?;
            struct Progress;
            impl wallet::sync_observer::SyncObserver for Progress {}
            let tip = session.sync(&mut Progress).await?;
            print(&cli, &serde_json::json!({ "tip": tip }), || {
                println!("synced to block {tip}");
            });
            session.lock()
        }
        Command::Send { from, to, amount } => {
            transact(
                &cli,
                Intent::Transfer {
                    from: from.clone(),
                    to: to.clone(),
                    amount: *amount,
                },
            )
            .await
        }
        Command::Shield { from, to, amount } => {
            transact(
                &cli,
                Intent::Shield {
                    from: from.clone(),
                    to: to.clone(),
                    amount: *amount,
                },
            )
            .await
        }
        Command::Status => {
            let (session, _) = open(&cli).await?;
            let status = session.status()?;
            println!("{}", serde_json::to_string_pretty(&status)?);
            session.lock()
        }
        Command::Zones => {
            let zones = data_dir(&cli)?.zones()?;
            println!("{}", serde_json::to_string_pretty(&zones)?);
            Ok(())
        }
        Command::Reveal => {
            let (mut session, pw) = open(&cli).await?;
            let again = if noninteractive().is_some() {
                pw
            } else {
                rpassword::prompt_password("Password again to show the phrase: ")?
            };
            let phrase = session.reveal_phrase(&again)?;
            println!("{}", *phrase);
            session.lock()
        }
        Command::Password => {
            let (mut session, pw) = open(&cli).await?;
            let new = new_password()?;
            session.change_password(&pw, &new)?;
            session.lock()
        }
        Command::AutoLock { seconds } => {
            let (mut session, _) = open(&cli).await?;
            session.set_auto_lock(*seconds)?;
            session.lock()
        }
    }
}

#[tokio::main]
async fn main() {
    let cli = Cli::parse();
    let json = cli.json;
    if let Err(e) = run(cli).await {
        let code = code_of(&e) as i64;
        if json {
            println!(
                "{}",
                serde_json::json!({ "error": { "code": code, "message": format!("{e:#}") } })
            );
        } else {
            eprintln!("error: {e:#}");
        }
        std::process::exit(1);
    }
}
