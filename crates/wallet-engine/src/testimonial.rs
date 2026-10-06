//! The Logos Kit testimonial program: posting, reading, adoption evidence and
//! deployment.
//!
//! The wallet recognises the program by its **image**, never by an address:
//! `programs/testimonial/artifacts/build.json` records the image our pinned
//! docker build produces. A program is trusted (testimonial decoder, posts,
//! `verified_local`) only if its live header runs exactly that image **and**
//! nobody can change it: the header is immutable, or it is the registry's
//! deployment. A public transaction names the program account, not its
//! image, so an upgradeable copy run by someone else could swap its code
//! between approval and inclusion, with the signer's authorization.

use std::{
    borrow::Cow,
    collections::{BTreeMap, BTreeSet, HashMap},
    sync::LazyLock,
    time::{SystemTime, UNIX_EPOCH},
};

use anyhow::{Context as _, Result, ensure};
use base64::{Engine as _, engine::general_purpose::STANDARD};
use lee::{AccountId, ProgramShardSelector, program::Program};
use serde::{Deserialize, Serialize};
use testimonial_core::{Instruction, Stats, Testimonial};
use wallet::{WalletCore, program_facades::program_loader::ProgramLoader};

use crate::{
    session::Session,
    tx::{CallAccount, Intent},
    verify::{self, ProgramCheck, Source, Status},
};

/// Our submission id for LP-0021.
pub const SUBMISSION: &str = "LP-0021/logos-kit";
/// LP-0021 adoption target: distinct authors overall, and per month over at
/// least two consecutive months.
pub const TARGET_TOTAL: usize = 150;
pub const TARGET_PER_MONTH: usize = 30;

const BUILD: &str = include_str!("../../../programs/testimonial/artifacts/build.json");
static PARSED: LazyLock<Option<Build>> = LazyLock::new(|| serde_json::from_str(BUILD).ok());

/// What our reproducible build of the program produced.
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Build {
    pub image_id: String,
    pub source: Source,
    /// Date the docker build produced this image (YYYY-MM-DD).
    pub built: String,
}

pub fn build() -> Option<&'static Build> {
    PARSED.as_ref()
}

/// Whether `image` is the testimonial program's.
pub fn is_image(image: &[u32; 8]) -> bool {
    build().is_some_and(|b| b.image_id == verify::image_hex(image))
}

/// A header check that [`verify`] classified as our program, fixed in place.
pub fn trusted(check: &ProgramCheck) -> bool {
    is_image(&check.image_id_words) && check.status == Status::VerifiedLocal
}

/// The program must be one we trust (see the module docs).
pub async fn check_program(core: &WalletCore, program: AccountId) -> Result<ProgramCheck> {
    let check = verify::check(core, program).await?;
    ensure!(
        is_image(&check.image_id_words),
        "{program} does not run the Logos Kit testimonial program (image {})",
        check.image_id
    );
    ensure!(
        trusted(&check),
        "{program} runs the testimonial image but its owner can still change it; \
         use the registry's deployment or an immutable one"
    );
    Ok(check)
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

/// The `Call` that posts: `[author (signs), stats(page), record]` (+
/// `stats(page - 1)` after page 0), all on the program's shard. The author
/// pays the fee.
pub fn post_call(
    program: AccountId,
    author: AccountId,
    submission: &str,
    page: u32,
    username: Option<&str>,
    text: &str,
    timestamp_ms: u64,
) -> Result<Intent> {
    testimonial_core::check_post(submission, username, text)?;
    let p = program.value();
    let data = borsh::to_vec(&Instruction::Post {
        submission: submission.to_owned(),
        page,
        username: username.map(str::to_owned),
        text: text.to_owned(),
        timestamp_ms,
    })?;
    let row = |id: [u8; 32], signer: bool| CallAccount {
        account: AccountId::new(id).to_string(),
        shard: None,
        signer,
    };
    let mut accounts = vec![
        row(*author.value(), true),
        row(testimonial_core::stats_account(p, submission, page), false),
        row(
            testimonial_core::record_account(p, submission, author.value()),
            false,
        ),
    ];
    if let Some(previous) = page.checked_sub(1) {
        accounts.push(row(
            testimonial_core::stats_account(p, submission, previous),
            false,
        ));
    }
    Ok(Intent::Call {
        from: author.to_string(),
        program: program.to_string(),
        accounts,
        data: STANDARD.encode(data),
    })
}

async fn shard(core: &WalletCore, id: [u8; 32], program: AccountId) -> Result<Vec<u8>> {
    let account = core
        .get_account_view(ProgramShardSelector::new(AccountId::new(id), program))
        .await?;
    Ok(account.data.shard(program).as_ref().to_vec())
}

/// Every stats page with authors, in order. The last one is the page to
/// post to, unless it is full (then the next).
pub async fn pages(core: &WalletCore, program: AccountId, submission: &str) -> Result<Vec<Stats>> {
    testimonial_core::check_submission(submission)?;
    let mut pages = Vec::new();
    for page in 0.. {
        let bytes = shard(
            core,
            testimonial_core::stats_account(program.value(), submission, page),
            program,
        )
        .await?;
        let stats = Stats::load(submission, page, &bytes)?;
        let full = stats.is_full();
        if stats.count() > 0 {
            pages.push(stats);
        }
        if !full {
            break;
        }
    }
    Ok(pages)
}

/// The first page that isn't full.
pub fn open_page(pages: &[Stats]) -> u32 {
    match pages.last() {
        Some(last) if last.is_full() => last.page + 1,
        Some(last) => last.page,
        None => 0,
    }
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
    expected: Testimonial,
}

/// The post a transaction makes, read from the exact message that is signed,
/// if it calls a program we trust.
pub fn watch(
    check: Option<&ProgramCheck>,
    message: Option<&lee::public_transaction::Message>,
) -> Option<Watch> {
    let (check, message) = (check?, message?);
    if !trusted(check) || message.program_account_id.to_string() != check.account {
        return None;
    }
    let Instruction::Post {
        submission,
        username,
        text,
        timestamp_ms,
        ..
    } = borsh::from_slice(&message.instruction_data).ok()?;
    let author = message.shard_selectors.first()?.account_id;
    Some(Watch {
        program: message.program_account_id,
        expected: Testimonial::new(submission, *author.value(), username, text, timestamp_ms),
    })
}

/// `Some(true)`: the record is exactly this post. `Some(false)`: nothing
/// was written (the program refused it). `None`: another post is there.
pub async fn observe(core: &WalletCore, w: &Watch) -> Result<Option<bool>> {
    let author = AccountId::new(w.expected.author);
    Ok(
        match record(core, w.program, &w.expected.submission, author).await? {
            Some(t) => (t == w.expected).then_some(true),
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
    /// Block and hash of the post (its first call to this program).
    pub post_block: Option<u64>,
    pub post_tx: Option<String>,
    /// Transactions the author itself signed strictly before the post, other
    /// than calls to the testimonial program: LP-0021's "prior activity".
    /// A faucet drop doesn't count (the faucet signs it).
    pub prior_txs: Vec<crate::activity::SignedTx>,
    pub has_prior_activity: bool,
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
    /// Only an immutable header guarantees earlier code didn't write records.
    pub immutable: bool,
    pub count: usize,
    pub pages: usize,
    /// The program's own monthly tally (summed over pages).
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
    /// Every program read is immutable (its whole history is this code).
    pub immutable: bool,
    /// Authors with prior activity (see [`Entry::prior_txs`]).
    pub qualified: usize,
    /// Qualified authors ≥ total, and two consecutive months with ≥ per_month
    /// new qualified authors each.
    pub qualified_total_met: bool,
    pub qualified_months_met: bool,
    /// Every requirement above, counting qualified authors only.
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
    /// New distinct authors per month: an author counts once, in the month
    /// of its earliest post across all programs.
    pub months: Vec<MonthCount>,
    pub distinct_authors: usize,
    /// Authors who posted under more than one program account (counted once).
    pub repeat_authors: Vec<String>,
    pub target: Target,
    pub entries: Vec<Entry>,
    /// Read before the records: every record here is at or before this block.
    pub tip: Tip,
    pub generated_ms: u64,
}

/// `cache`: a file the block scan resumes from (see [`crate::activity`]).
pub async fn evidence(
    core: &WalletCore,
    programs: &[AccountId],
    submission: &str,
    cache: Option<&std::path::Path>,
) -> Result<Evidence> {
    ensure!(!programs.is_empty(), "name at least one program account");
    let tip_id = core.get_last_block_id().await?;
    let tip = core
        .get_block(tip_id)
        .await?
        .with_context(|| format!("block {tip_id} not found"))?;
    let history = crate::activity::History::scan(core, tip_id, cache).await?;
    let mut qualified_first: HashMap<AccountId, u64> = HashMap::new();
    let mut entries = Vec::new();
    let mut summaries = Vec::new();
    let mut earliest: HashMap<AccountId, u64> = HashMap::new();
    let mut repeat = BTreeSet::new();
    for &program in programs {
        let check = check_program(core, program).await?;
        let pages = pages(core, program, submission).await?;
        let mut on_chain: BTreeMap<u32, u32> = BTreeMap::new();
        let mut recomputed: BTreeMap<u32, u32> = BTreeMap::new();
        let mut index = 0;
        for stats in &pages {
            for m in &stats.monthly {
                *on_chain.entry(m.yyyymm).or_default() += m.count;
            }
            for author in &stats.authors {
                let author = AccountId::new(*author);
                let t = record(core, program, submission, author)
                    .await?
                    .with_context(|| format!("{author} is counted but has no record"))?;
                let month = testimonial_core::yyyymm(t.timestamp_ms);
                *recomputed.entry(month).or_default() += 1;
                if let Some(first) = earliest.get_mut(&author) {
                    repeat.insert(author.to_string());
                    *first = (*first).min(t.timestamp_ms);
                } else {
                    earliest.insert(author, t.timestamp_ms);
                }
                let account = core
                    .get_account_view(ProgramShardSelector::native_balance(author))
                    .await?;
                let author_s = author.to_string();
                let program_s = program.to_string();
                let post = history.first_call(&author_s, &program_s).cloned();
                let prior = post
                    .as_ref()
                    .map(|p| history.before(&author_s, p.block, &program_s))
                    .unwrap_or_default();
                if !prior.is_empty() {
                    let first = qualified_first.entry(author).or_insert(t.timestamp_ms);
                    *first = (*first).min(t.timestamp_ms);
                }
                entries.push(Entry {
                    program: program.to_string(),
                    index,
                    author: author.to_string(),
                    username: t.username,
                    text: t.text,
                    timestamp_ms: t.timestamp_ms,
                    time: iso(t.timestamp_ms),
                    month: month_str(month),
                    post_block: post.as_ref().map(|p| p.block),
                    post_tx: post.map(|p| p.hash),
                    has_prior_activity: !prior.is_empty(),
                    prior_txs: prior,
                    balance: account.data.native_balance().unwrap_or(0).to_string(),
                });
                index += 1;
            }
        }
        summaries.push(ProgramSummary {
            account: program.to_string(),
            immutable: check.immutable,
            count: index,
            pages: pages.len(),
            monthly: on_chain
                .iter()
                .map(|(&m, &count)| MonthCount {
                    month: month_str(m),
                    count: count as usize,
                })
                .collect(),
            consistent: on_chain == recomputed,
        });
    }
    let mut months: BTreeMap<u32, usize> = BTreeMap::new();
    for &first in earliest.values() {
        *months.entry(testimonial_core::yyyymm(first)).or_default() += 1;
    }
    let distinct = earliest.len();
    let months_met = two_months(&months);
    let immutable = summaries.iter().all(|p| p.immutable);
    let mut qualified_months: BTreeMap<u32, usize> = BTreeMap::new();
    for &first in qualified_first.values() {
        *qualified_months
            .entry(testimonial_core::yyyymm(first))
            .or_default() += 1;
    }
    let qualified = qualified_first.len();
    let qualified_months_met = two_months(&qualified_months);
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
        repeat_authors: repeat.into_iter().collect(),
        target: Target {
            total: TARGET_TOTAL,
            per_month: TARGET_PER_MONTH,
            total_met: distinct >= TARGET_TOTAL,
            months_met,
            immutable,
            qualified,
            qualified_total_met: qualified >= TARGET_TOTAL,
            qualified_months_met,
            met: qualified >= TARGET_TOTAL && qualified_months_met && immutable,
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

/// Two consecutive calendar months with ≥ [`TARGET_PER_MONTH`] each.
fn two_months(months: &BTreeMap<u32, usize>) -> bool {
    months.iter().any(|(&m, &n)| {
        n >= TARGET_PER_MONTH
            && months
                .get(&testimonial_core::next_month(m))
                .is_some_and(|&k| k >= TARGET_PER_MONTH)
    })
}

fn month_str(yyyymm: u32) -> String {
    format!("{}-{:02}", yyyymm / 100, yyyymm % 100)
}

/// `YYYY-MM-DD HH:MM:SS UTC`.
pub fn iso(ms: u64) -> String {
    let secs = ms / 1000;
    let (h, m, s) = (secs / 3600 % 24, secs / 60 % 60, secs % 60);
    let (y, mo, d) = testimonial_core::civil(ms);
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
            let id = self.new_system_account("Program account")?.account_id;
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
        assert_eq!(month_str(202_611), "2026-11");
    }
}
