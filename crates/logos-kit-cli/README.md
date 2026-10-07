# logos-kit

The Logos Kit wallet on the command line. It runs the same engine and approval
policy as the Basecamp wallet: a transaction is built, shown decoded with its
fee, confirmed on the terminal, and only then signed.

```sh
git clone https://github.com/logos-kit/logos-kit && cd logos-kit
scripts/lez-vendor.sh                     # the pinned LEZ source + our patches into vendor/lez
cargo install --path crates/logos-kit-cli
logos-kit --help
```

Requirements: Rust 1.98.1 (`rust-toolchain.toml`) and git; Xcode command-line
tools on macOS; `clang`, `libclang-dev`, `cmake`, `pkg-config` and
`libssl-dev` on Linux. `verify-program` and `testimonial build` also need
Docker. A walkthrough of the common commands is in the
[root README](../../README.md#use-it-from-the-cli-step-by-step) and the
[CLI docs](https://logos-kit-docs.vercel.app/docs/wallet/cli).

## Global flags

| Flag | Env | Default | Meaning |
|---|---|---|---|
| `--home <dir>` | `LOGOS_KIT_HOME` | `~/.logos-kit` | The wallet's data folder |
| `--zone <id>` | `LOGOS_KIT_ZONE` | `lez-testnet` | The network: `lez-testnet` (official LEZ testnet), `lez-preview` (Logos Kit's earlier 0.3 network), `lez-local` (`http://127.0.0.1:3040`), or one added with `--sequencer` |
| `--sequencer <url>` | | | Talk to a zone that isn't built in (with `--zone <id>`) |
| `--yes` | | | Skip the confirmation. Works only with `LOGOS_KIT_PASSWORD` set |
| `--json` | | | Print results as JSON. Commands that spend also need `--yes` |
| `--ack-unknown` | | | With `--yes`: also approve a call the wallet can't decode |

`LOGOS_KIT_PASSWORD` supplies the password without a prompt (scripts, CI).
With `--json`, an error prints `{"error": {"code", "message"}}`; any error exits
with status 1.

## Amounts

The native token is LOGOS (LGO); 1 LGO = 10^9 lepta. `--amount` takes LGO when
written with a decimal point or an `LGO` suffix (`2.5`, `2.5LGO`, `"3 LGO"`, at
most 9 decimals, never rounded), and lepta as a whole number (`42`). With
`--token` it is a whole number of the token's base units. Human output shows
LGO; `--json` stays in lepta.

## Commands

### Wallet

| Command | What it does |
|---|---|
| `init` | Create a wallet and show its recovery phrase once (with `--json` the phrase goes to stderr, for restore tests) |
| `restore --from-date YYYY-MM-DD` / `--from-genesis` | Restore from a recovery phrase (asked on the terminal, or `LOGOS_KIT_PHRASE`). The date skips earlier blocks; run `sync` afterwards |
| `sync` | Catch up with the chain |
| `status` | Zone, sync and network state, as JSON |
| `zones` | Zones this wallet knows, as JSON |
| `reveal` | Show the recovery phrase (asks the password again) |
| `password` | Change the wallet password |
| `auto-lock <seconds>` | Lock after this long without use (60–86400; 900 by default) |
| `backup export <file>` | Write an encrypted backup (the file must not exist yet; mode 0600) |
| `backup import <file>` | Restore a backup into an empty data folder; checks the password it was made with |

### Accounts

| Command | What it does |
|---|---|
| `account new [--private]` | Add a public (default) or private account; prints its id |
| `account list` | Kind, id, derivation path and name of every account |
| `account label <account> [name]` | Name an account (up to 32 characters); without a name, clear it |
| `account import` | Import a public account by private key (asked on the terminal, or `LOGOS_KIT_IMPORT_KEY`) |
| `account keys <account>` | The two keys (npk, vpk lines) others need to pay a private account privately. Holds no secret |
| `balance <account> [--token <definition>]` | Native balance in LGO, or a token's balance in base units |

### Transfers

| Command | What it does |
|---|---|
| `send --from <a> --to <b> --amount <n> [--token <definition>]` | Send LGO or a token. The route follows from the accounts: public, shield (into your private account), deshield (out of it) or private to private |
| `send --from <a> --to-keys <file> --amount <n>` | Pay someone else's private account from their `account keys` file (or `--to-npk <hex> --to-vpk <hex>`, optional `--to-identifier`) |
| `shield …` | Same flags as `send`; refuses unless the route is public to your private account |
| `deshield …` (alias `unshield`) | Same flags as `send`; refuses unless the route is your private account to public |
| `faucet <account> [--via <public>]` | Test funds from the zone's drip faucet (1 LGO on the testnet). A private account is funded through a public one (`--via`), then shielded |
| `faucet <account> --url <drip url>` | Use another drip service (`LOGOS_KIT_FAUCET_URL`) |
| `faucet <account> --key-env <VAR> [--drop <lepta>]` | Local chains: pay from a funded key held in the env var `VAR` (default drop 1,000,000 lepta) |
| `call --from <a> --program <p> --account <id[:shard][:signer]>… --data <base64>` | Call any program, as an app would propose it |

Private routes prove on this machine and take minutes; keep the command
running. Each spend prints the route, the accounts, every decoded effect, the
program and its verification status, the fee (an estimate at today's rate and
its cap, or none for a private transaction) and the request hash, then asks
`Approve? [y/N]`. Afterwards it prints the transaction hash, the block, the
outcome and the fee paid.

### Tokens

| Command | What it does |
|---|---|
| `token create --name <name> --supply <n> --holder <public>` | Create a fungible token. A new account becomes the definition; the whole supply goes to `--holder`, whose token slot must be empty |
| `token list` | Tokens in your accounts (their own slot and associated token accounts) |
| `token track <definition>` | Also look for this token's associated token accounts |
| `token ata <owner> <definition>` | The associated token account address of `owner` for a token |

### Programs

| Command | What it does |
|---|---|
| `program <address or builtin name>` | A program's header and its source-verification status |
| `verify-program <address>` | Rebuild the program from the source the registry names, in docker, and compare it with what is deployed. A match is saved in the wallet folder, and this wallet's approvals then show the program as verified. Other sources: `--repo --commit --guest-path --bin [--features]`; `--docker-tag` (default `r0.1.91.1`) |
| `verify-program --builtins [--repo <url>]` | Rebuild the LEZ builtins the wallet decodes and print the evidence (`registry/builtins.json`) |

### Testimonials (LP-0021)

| Command | What it does |
|---|---|
| `testimonial post --from <public> --text <text> [--username <name>]` | Post a testimonial (text up to 280 bytes, name up to 32 bytes). The account pays the fee and is the author on chain; one post per account |
| `testimonial list` | A submission's testimonials, in posting order |
| `testimonial evidence [--snapshot <dir>] [--cache <file>]` | Adoption evidence from chain data: distinct authors per month, each author's prior activity, and the LP-0021 target. Repeat `--program` for a redeploy |
| `testimonial build [--commit <rev>]` | Build the program from a commit of this repo in the pinned docker builder; writes `testimonial.bin` and `build.json` |
| `testimonial deploy --payer <public> [--upgradeable]` | Deploy the built program (immutable unless `--upgradeable`) and print its registry entry |

`post`, `list` and `evidence` take `--program` (default: the registry's program
for the zone) and `--submission` (default `LP-0021/logos-kit`).

## Scripts

```sh
export LOGOS_KIT_PASSWORD=…  LOGOS_KIT_HOME="$(mktemp -d)"
logos-kit init --json
A=$(logos-kit account new --json | jq -r .accountId)
logos-kit faucet "$A" --yes --json
logos-kit send --from "$A" --to <b> --amount 1000 --yes --json   # {"lifecycle": …, "outcome": "success", "block": …}
```

[`e2e/demo.sh`](../../e2e/demo.sh) and [`e2e/preview-flows.sh`](../../e2e/preview-flows.sh)
run every flow this way.
