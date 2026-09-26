//! The Logos Kit testimonial program: posting, reading, adoption evidence and
//! deployment.
//!
//! The wallet recognises the program by its **image**, never by an address:
//! `programs/testimonial/artifacts/build.json` records the image our pinned
//! docker build produces, and only a program whose live header runs exactly
//! that image gets the testimonial decoder or a post. Any deployment (local,
//! staging, production) qualifies; any other code at a claimed address is
//! refused, because a signer's authorization reaches every program it calls.

use std::{
    borrow::Cow,
    time::{SystemTime, UNIX_EPOCH},
};

use anyhow::{Context as _, Result, ensure};
use base64::{Engine as _, engine::general_purpose::STANDARD};
use lee::{AccountId, ProgramShardSelector, program::Program};
use serde::{Deserialize, Serialize};
use testimonial_core::{Instruction, Stats, Testimonial};
use wallet::{WalletCore, program_facades::program_loader::ProgramLoader};

use crate::{
    session::{AccountKind, Session},
    tx::{CallAccount, Intent},
    verify::{self, Source},
};

/// Our submission id for LP-0021.
pub const SUBMISSION: &str = "LP-0021/logos-kit";
/// LP-0021 adoption target: distinct authors overall, and per month over at
/// least two consecutive months.
pub const TARGET_TOTAL: usize = 150;
pub const TARGET_PER_MONTH: usize = 30;

const BUILD: &str = include_str!("../../../programs/testimonial/artifacts/build.json");

/// What our reproducible build of the program produced.
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Build {
    pub image_id: String,
    pub source: Source,
    /// Date the docker build produced this image (YYYY-MM-DD).
    pub built: String,
}

pub fn build() -> Option<Build> {
    serde_json::from_str(BUILD).ok()
}

/// Whether `image` is the testimonial program's.
pub fn is_image(image: &[u32; 8]) -> bool {
    build().is_some_and(|b| b.image_id == verify::image_hex(image))
}

/// The program's live header must run our image.
pub async fn check_program(core: &WalletCore, program: AccountId) -> Result<()> {
    let header = verify::read_header(core, program)
        .await?
        .with_context(|| format!("no program is deployed at {program}"))?;
    ensure!(
        is_image(&header.image_id),
        "{program} does not run the Logos Kit testimonial program (image {})",
        verify::image_hex(&header.image_id)
    );
    Ok(())
}

/// The testimonial program the registry names for `chain`.
pub fn default_program(chain: &str) -> Option<String> {
    verify::registry_program("testimonial", chain)
}

pub fn now_ms() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_or(0, |d| u64::try_from(d.as_millis()).unwrap_or(u64::MAX))
}

/// The `Call` that posts: `[author (signs), stats, record]`, all on the
/// program's shard. The author pays the fee.
pub fn post_call(
    program: AccountId,
    author: AccountId,
    submission: &str,
    username: Option<&str>,
    text: &str,
    timestamp_ms: u64,
) -> Result<Intent> {
    testimonial_core::check_post(submission, username, text)?;
    let p = program.value();
    let data = borsh::to_vec(&Instruction::Post {
        submission: submission.to_owned(),
        username: username.map(str::to_owned),
        text: text.to_owned(),
        timestamp_ms,
    })?;
    let row = |id: [u8; 32], signer: bool| CallAccount {
        account: AccountId::new(id).to_string(),
        shard: None,
        signer,
    };
    Ok(Intent::Call {
        from: author.to_string(),
        program: program.to_string(),
        accounts: vec![
            row(*author.value(), true),
            row(testimonial_core::stats_account(p, submission), false),
            row(
                testimonial_core::record_account(p, submission, author.value()),
                false,
            ),
        ],
        data: STANDARD.encode(data),
    })
}

async fn shard(core: &WalletCore, id: [u8; 32], program: AccountId) -> Result<Vec<u8>> {
    let account = core
        .get_account_view(ProgramShardSelector::new(AccountId::new(id), program))
        .await?;
    Ok(account.data.shard(program).as_ref().to_vec())
}

pub async fn stats(core: &WalletCore, program: AccountId, submission: &str) -> Result<Stats> {
    testimonial_core::check_submission(submission)?;
    let bytes = shard(
        core,
        testimonial_core::stats_account(program.value(), submission),
        program,
    )
    .await?;
    Ok(Stats::load(submission, &bytes)?)
}

pub async fn record(
    core: &WalletCore,
    program: AccountId,
    submission: &str,
    author: AccountId,
) -> Result<Option<Testimonial>> {
    let bytes = shard(
        core,
        testimonial_core::record_account(program.value(), submission, author.value()),
        program,
    )
    .await?;
    if bytes.is_empty() {
        return Ok(None);
    }
    let t = Testimonial::from_bytes(&bytes)?;
    ensure!(
        t.submission == submission && t.author == *author.value(),
        "record of {author} names another submission or author"
    );
    Ok(Some(t))
}

/// A submitted post, to settle its outcome from chain state: v0.3 includes
/// failed transactions, so inclusion alone says nothing.
#[derive(Clone, Debug)]
pub struct Watch {
    program: AccountId,
    submission: String,
    author: AccountId,
    username: Option<String>,
    text: String,
}

/// The post a reviewed transaction makes, if it runs our program's image.
pub fn watch(review: &crate::tx::Review) -> Option<Watch> {
    let program_check = review.program.as_ref()?;
    if !is_image(&program_check.image_id_words) {
        return None;
    }
    let program = crate::decode::account_id(&program_check.account).ok()?;
    let id = |s: &str| crate::decode::account_id(s.strip_prefix("Public/").unwrap_or(s)).ok();
    match &review.intent {
        Intent::Testimonial {
            from,
            submission,
            username,
            text,
            ..
        } => Some(Watch {
            program,
            submission: submission.clone(),
            author: id(from)?,
            username: username.clone(),
            text: text.clone(),
        }),
        Intent::Call { accounts, data, .. } => {
            let bytes = STANDARD.decode(data).ok()?;
            let Instruction::Post {
                submission,
                username,
                text,
                ..
            } = borsh::from_slice(&bytes).ok()?;
            Some(Watch {
                program,
                submission,
                author: id(&accounts.first()?.account)?,
                username,
                text,
            })
        }
        Intent::Transfer { .. } => None,
    }
}

/// `Some(true)`: the record holds this post. `Some(false)`: nothing was
/// written (the program refused it). `None`: a different post is there.
pub async fn observe(core: &WalletCore, w: &Watch) -> Result<Option<bool>> {
    Ok(
        match record(core, w.program, &w.submission, w.author).await? {
            Some(t) => (t.text == w.text && t.username == w.username).then_some(true),
            None => Some(false),
        },
    )
}

/// One testimonial, with what an evaluator checks about its author.
#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Entry {
    pub program: String,
    /// Position in the program's stats (posting order).
    pub index: usize,
    pub author: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub username: Option<String>,
    pub text: String,
    pub timestamp_ms: u64,
    pub time: String,
    /// `YYYY-MM`.
    pub month: String,
    /// Transactions the author signed besides this one (public nonce − 1).
    pub other_txs: String,
    /// Native balance now.
    pub balance: String,
}

#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct MonthCount {
    pub month: String,
    pub count: usize,
}

#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ProgramSummary {
    pub account: String,
    pub count: usize,
    /// The program's own monthly tally.
    pub monthly: Vec<MonthCount>,
    /// The tally equals the one recomputed from the records.
    pub consistent: bool,
}

#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Target {
    pub total: usize,
    pub per_month: usize,
    /// Distinct authors ≥ total.
    pub total_met: bool,
    /// Two consecutive calendar months with ≥ per_month new authors each.
    pub months_met: bool,
    pub met: bool,
}

#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Tip {
    pub block: u64,
    pub hash: String,
    pub timestamp_ms: u64,
}

/// Adoption evidence for one submission across one or more program
/// accounts (a redeploy or a chain reset adds one), read from chain data only.
#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Evidence {
    pub submission: String,
    pub programs: Vec<ProgramSummary>,
    /// New distinct authors per month (an author counts once, at its first post).
    pub months: Vec<MonthCount>,
    pub distinct_authors: usize,
    /// Authors who posted under more than one program account (counted once).
    pub repeat_authors: Vec<String>,
    pub target: Target,
    pub entries: Vec<Entry>,
    pub tip: Tip,
    pub generated_ms: u64,
}

pub async fn evidence(
    core: &WalletCore,
    programs: &[AccountId],
    submission: &str,
) -> Result<Evidence> {
    ensure!(!programs.is_empty(), "name at least one program account");
    let mut entries = Vec::new();
    let mut summaries = Vec::new();
    let mut seen = std::collections::HashSet::new();
    let mut repeat = Vec::new();
    let mut months: std::collections::BTreeMap<u32, usize> = Default::default();
    for &program in programs {
        check_program(core, program).await?;
        let stats = stats(core, program, submission).await?;
        let mut recomputed: std::collections::BTreeMap<u32, u32> = Default::default();
        for (index, author) in stats.authors.iter().enumerate() {
            let author = AccountId::new(*author);
            let t = record(core, program, submission, author)
                .await?
                .with_context(|| format!("{author} is counted but has no record"))?;
            let month = testimonial_core::yyyymm(t.timestamp_ms);
            *recomputed.entry(month).or_default() += 1;
            if seen.insert(author) {
                *months.entry(month).or_default() += 1;
            } else {
                repeat.push(author.to_string());
            }
            let account = core
                .get_account_view(ProgramShardSelector::native_balance(author))
                .await?;
            entries.push(Entry {
                program: program.to_string(),
                index,
                author: author.to_string(),
                username: t.username,
                text: t.text,
                timestamp_ms: t.timestamp_ms,
                time: iso(t.timestamp_ms),
                month: month_str(month),
                other_txs: account.nonce.0.saturating_sub(1).to_string(),
                balance: account.data.native_balance().unwrap_or(0).to_string(),
            });
        }
        let on_chain: std::collections::BTreeMap<u32, u32> =
            stats.monthly.iter().map(|m| (m.yyyymm, m.count)).collect();
        summaries.push(ProgramSummary {
            account: program.to_string(),
            count: stats.count(),
            monthly: stats
                .monthly
                .iter()
                .map(|m| MonthCount {
                    month: month_str(m.yyyymm),
                    count: m.count as usize,
                })
                .collect(),
            consistent: on_chain == recomputed,
        });
    }
    let distinct = seen.len();
    let months_met = months.iter().any(|(&m, &n)| {
        n >= TARGET_PER_MONTH
            && months
                .get(&next_month(m))
                .is_some_and(|&k| k >= TARGET_PER_MONTH)
    });
    let tip_id = core.get_last_block_id().await?;
    let tip = core
        .get_block(tip_id)
        .await?
        .with_context(|| format!("block {tip_id} not found"))?;
    Ok(Evidence {
        submission: submission.to_owned(),
        programs: summaries,
        months: months
            .into_iter()
            .map(|(m, count)| MonthCount {
                month: month_str(m),
                count,
            })
            .collect(),
        distinct_authors: distinct,
        repeat_authors: repeat,
        target: Target {
            total: TARGET_TOTAL,
            per_month: TARGET_PER_MONTH,
            total_met: distinct >= TARGET_TOTAL,
            months_met,
            met: distinct >= TARGET_TOTAL && months_met,
        },
        entries,
        tip: Tip {
            block: tip.header.block_id,
            hash: tip.header.hash.to_string(),
            timestamp_ms: tip.header.timestamp,
        },
        generated_ms: now_ms(),
    })
}

const fn next_month(yyyymm: u32) -> u32 {
    if yyyymm % 100 == 12 {
        (yyyymm / 100 + 1) * 100 + 1
    } else {
        yyyymm + 1
    }
}

fn month_str(yyyymm: u32) -> String {
    format!("{}-{:02}", yyyymm / 100, yyyymm % 100)
}

/// `YYYY-MM-DD HH:MM:SS UTC`.
pub fn iso(ms: u64) -> String {
    let secs = ms / 1000;
    let (h, m, s) = (secs / 3600 % 24, secs / 60 % 60, secs % 60);
    let z = i64::try_from(secs / 86_400).unwrap_or(0) + 719_468;
    let era = z.div_euclid(146_097);
    let doe = z - era * 146_097;
    let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let mo = if mp < 10 { mp + 3 } else { mp - 9 };
    let y = yoe + era * 400 + i64::from(mo <= 2);
    format!("{y:04}-{mo:02}-{d:02} {h:02}:{m:02}:{s:02} UTC")
}

/// The program binary's image id.
pub fn image_of(elf: &[u8]) -> Result<[u32; 8]> {
    Ok(Program::new(Cow::Owned(elf.to_vec()))
        .map_err(|e| anyhow::anyhow!("not a RISC Zero program binary: {e}"))?
        .id())
}

impl Session {
    /// Deploy `elf` through LEZ's program loader: a fresh public account of
    /// this wallet becomes the header (its key can upgrade a mutable
    /// deploy; derived from the phrase, so it is recoverable), fresh ones hold
    /// the segments, and `payer` pays every transaction. Owner only; waits
    /// for each transaction. Returns the program account.
    pub async fn deploy_program(
        &mut self,
        elf: Vec<u8>,
        payer: AccountId,
        immutable: bool,
    ) -> Result<AccountId> {
        self.connect().await?;
        let core = self.core().context("not connected")?;
        ensure!(
            core.get_account_public_signing_key(payer).is_some(),
            "{payer} is not a public account of this wallet"
        );
        let binary = risc0_binfmt::ProgramBinary::decode(&elf)
            .map_err(|e| anyhow::anyhow!("not a RISC Zero program binary: {e}"))?;
        let segments = binary
            .user_elf
            .len()
            .div_ceil(program_loader_core::MAX_SEGMENT_DATA_LEN);
        let mut fresh = || -> Result<AccountId> {
            let id = self.new_account(AccountKind::Public)?.account_id;
            crate::decode::account_id(&id)
        };
        let header = fresh()?;
        let segment_ids = (0..segments).map(|_| fresh()).collect::<Result<Vec<_>>>()?;
        let core = self.core().context("not connected")?;
        ProgramLoader(core)
            .deploy(header, &segment_ids, elf, immutable, Some(payer))
            .await?;
        self.persist_now()?;
        Ok(header)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn times_and_months() {
        assert_eq!(iso(1_709_251_199_999), "2024-02-29 23:59:59 UTC");
        assert_eq!(iso(1_798_761_600_000), "2027-01-01 00:00:00 UTC");
        assert_eq!(next_month(202_612), 202_701);
        assert_eq!(month_str(202_611), "2026-11");
    }
}
