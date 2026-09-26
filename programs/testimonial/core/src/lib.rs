//! Shared types for the Logos Kit testimonial program (LEZ 0.3).
//!
//! The guest, the wallet engine and the evidence exporter all use this crate,
//! so it depends only on `borsh` and `sha2` (never on a second `lee_core`).
//!
//! Layout, per submission id `sub` and program account `P` (all on `P`'s
//! own shard, which only `P` can write):
//!
//! - `stats(sub)`: [`Stats`], every author in posting order plus monthly
//!   tallies. Reading it is enough to enumerate a submission.
//! - `record(sub, author)`: one [`Testimonial`]. It must be empty to post, so
//!   an account posts at most once per submission (distinct accounts).
//!
//! A post names both accounts up front, so posts never race on an index:
//! public transactions apply in order against current state.

use borsh::{BorshDeserialize, BorshSerialize};
use sha2::{Digest as _, Sha256};

/// Submission ids are printable ASCII, e.g. `LP-0021/logos-kit`.
pub const MAX_SUBMISSION: usize = 32;
pub const MAX_USERNAME: usize = 32;
pub const MAX_TEXT: usize = 280;
/// Authors per submission. Keeps `stats` under the 100 KiB shard cap.
pub const MAX_AUTHORS: usize = 3000;
/// The block may be at most this much *before* the claimed time (clock skew).
pub const EARLY_MS: u64 = 120_000;
/// The block may be at most this much *after* the claimed time: the user reads
/// the approval sheet (the wallet's deadline is 5 min) before it is sent.
pub const LATE_MS: u64 = 600_000;

const RECORD_VERSION: u8 = 1;
const STATS_VERSION: u8 = 1;

/// LEZ `AccountId::for_public_pda` prefix (`lee_core/src/program/mod.rs`).
const PDA_PREFIX: &[u8; 32] = b"/LEE/v0.2/AccountId/PDA/\x00\x00\x00\x00\x00\x00\x00\x00";
const SEED_DOMAIN: &[u8] = b"logos-kit/testimonial/v1/";

/// Append-only: borsh encodes the variant index.
#[derive(Clone, Debug, PartialEq, Eq, BorshSerialize, BorshDeserialize)]
pub enum Instruction {
    /// Accounts, all selecting this program's shard: `[author (signs), stats(sub),
    /// record(sub, author)]`.
    Post {
        submission: String,
        username: Option<String>,
        text: String,
        /// Unix ms. The chain checks it against the block time (see [`window`]).
        timestamp_ms: u64,
    },
}

/// What `plan` asks `apply` to do to one shard.
#[derive(Clone, Debug, PartialEq, Eq, BorshSerialize, BorshDeserialize)]
pub enum Effect {
    /// On `stats`: append the author (never twice) and count the month.
    Count {
        submission: String,
        author: [u8; 32],
        timestamp_ms: u64,
    },
    /// On `record`: write a borsh [`Testimonial`] into an empty shard.
    Create(Vec<u8>),
}

#[derive(Clone, Debug, PartialEq, Eq, BorshSerialize, BorshDeserialize)]
pub struct Testimonial {
    pub version: u8,
    pub submission: String,
    pub author: [u8; 32],
    pub username: Option<String>,
    pub text: String,
    pub timestamp_ms: u64,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, BorshSerialize, BorshDeserialize)]
pub struct Month {
    /// UTC calendar month as `yyyymm`, e.g. `202611`.
    pub yyyymm: u32,
    pub count: u32,
}

#[derive(Clone, Debug, PartialEq, Eq, BorshSerialize, BorshDeserialize)]
pub struct Stats {
    pub version: u8,
    pub submission: String,
    pub first_ms: u64,
    pub last_ms: u64,
    /// Ascending by month.
    pub monthly: Vec<Month>,
    /// Posting order; an author's index is its position.
    pub authors: Vec<[u8; 32]>,
}

/// The `Posted` event. Public data only (it repeats the record's header).
#[derive(Clone, Debug, PartialEq, Eq, BorshSerialize, BorshDeserialize)]
pub struct Posted {
    pub submission: String,
    pub author: [u8; 32],
    pub timestamp_ms: u64,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Error {
    Submission,
    Username,
    Text,
    AlreadyPosted,
    Full,
    Timestamp,
    Decode,
}

impl core::fmt::Display for Error {
    fn fmt(&self, f: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {
        f.write_str(match self {
            Self::Submission => "submission id must be 1-32 printable ASCII characters",
            Self::Username => {
                "username must be 1-32 bytes, trimmed, without control or direction characters"
            }
            Self::Text => {
                "text must be 1-280 bytes, not blank, without control (except newline) or direction characters"
            }
            Self::AlreadyPosted => "this account already posted a testimonial for this submission",
            Self::Full => "this submission has reached its testimonial limit",
            Self::Timestamp => "timestamp is out of range",
            Self::Decode => "stored data does not decode",
        })
    }
}

impl std::error::Error for Error {}

/// Bidi controls reorder what an explorer shows; a testimonial has no use for them.
const fn is_direction_control(c: char) -> bool {
    matches!(c, '\u{200E}' | '\u{200F}' | '\u{202A}'..='\u{202E}' | '\u{2066}'..='\u{2069}')
}

pub fn check_submission(s: &str) -> Result<(), Error> {
    let ok = (1..=MAX_SUBMISSION).contains(&s.len()) && s.bytes().all(|b| b.is_ascii_graphic());
    ok.then_some(()).ok_or(Error::Submission)
}

pub fn check_username(s: &str) -> Result<(), Error> {
    let ok = (1..=MAX_USERNAME).contains(&s.len())
        && s.trim() == s
        && !s.chars().any(|c| c.is_control() || is_direction_control(c));
    ok.then_some(()).ok_or(Error::Username)
}

pub fn check_text(s: &str) -> Result<(), Error> {
    let ok = (1..=MAX_TEXT).contains(&s.len())
        && !s.trim().is_empty()
        && !s
            .chars()
            .any(|c| (c.is_control() && c != '\n') || is_direction_control(c));
    ok.then_some(()).ok_or(Error::Text)
}

pub fn check_post(submission: &str, username: Option<&str>, text: &str) -> Result<(), Error> {
    check_submission(submission)?;
    username.map(check_username).transpose()?;
    check_text(text)
}

/// The block-time window `[from, to)` a post claiming `timestamp_ms` lands in.
pub fn window(timestamp_ms: u64) -> Result<(u64, u64), Error> {
    let from = timestamp_ms.checked_sub(EARLY_MS).ok_or(Error::Timestamp)?;
    let to = timestamp_ms.checked_add(LATE_MS).ok_or(Error::Timestamp)?;
    Ok((from, to))
}

fn seed(tag: &[u8], submission: &str, extra: &[u8]) -> [u8; 32] {
    let len = u8::try_from(submission.len()).expect("a checked submission id is short");
    let mut h = Sha256::new();
    h.update(SEED_DOMAIN);
    h.update(tag);
    h.update([0, len]);
    h.update(submission.as_bytes());
    h.update(extra);
    h.finalize().into()
}

pub fn stats_seed(submission: &str) -> [u8; 32] {
    seed(b"stats", submission, &[])
}

pub fn record_seed(submission: &str, author: &[u8; 32]) -> [u8; 32] {
    seed(b"record", submission, author)
}

/// LEZ's public PDA derivation: `sha256(prefix || program || seed)`.
pub fn pda(program: &[u8; 32], seed: &[u8; 32]) -> [u8; 32] {
    let mut h = Sha256::new();
    h.update(PDA_PREFIX);
    h.update(program);
    h.update(seed);
    h.finalize().into()
}

pub fn stats_account(program: &[u8; 32], submission: &str) -> [u8; 32] {
    pda(program, &stats_seed(submission))
}

pub fn record_account(program: &[u8; 32], submission: &str, author: &[u8; 32]) -> [u8; 32] {
    pda(program, &record_seed(submission, author))
}

/// First 8 bytes of `sha256("testimonial::Posted")` (LEZ's event convention).
pub fn posted_selector() -> [u8; 8] {
    let d: [u8; 32] = Sha256::digest(b"testimonial::Posted").into();
    let mut s = [0; 8];
    s.copy_from_slice(&d[..8]);
    s
}

/// UTC `yyyymm` of a Unix-ms time (Hinnant's `civil_from_days`).
pub fn yyyymm(timestamp_ms: u64) -> u32 {
    let z = i64::try_from(timestamp_ms / 86_400_000).expect("days fit i64") + 719_468;
    let era = z.div_euclid(146_097);
    let doe = z - era * 146_097;
    let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let m = if mp < 10 { mp + 3 } else { mp - 9 };
    let y = yoe + era * 400 + i64::from(m <= 2);
    u32::try_from(y * 100 + m).expect("a Unix-ms year fits u32")
}

impl Testimonial {
    pub fn new(
        submission: String,
        author: [u8; 32],
        username: Option<String>,
        text: String,
        timestamp_ms: u64,
    ) -> Self {
        Self {
            version: RECORD_VERSION,
            submission,
            author,
            username,
            text,
            timestamp_ms,
        }
    }

    pub fn to_bytes(&self) -> Vec<u8> {
        borsh::to_vec(self).expect("borsh serialization is infallible")
    }

    pub fn from_bytes(bytes: &[u8]) -> Result<Self, Error> {
        borsh::from_slice(bytes).map_err(|_| Error::Decode)
    }
}

impl Stats {
    pub const fn new(submission: String) -> Self {
        Self {
            version: STATS_VERSION,
            submission,
            first_ms: 0,
            last_ms: 0,
            monthly: Vec::new(),
            authors: Vec::new(),
        }
    }

    /// An empty shard is a submission nobody posted to yet.
    pub fn load(submission: &str, bytes: &[u8]) -> Result<Self, Error> {
        if bytes.is_empty() {
            return Ok(Self::new(submission.to_owned()));
        }
        let stats: Self = borsh::from_slice(bytes).map_err(|_| Error::Decode)?;
        if stats.submission != submission {
            return Err(Error::Decode);
        }
        Ok(stats)
    }

    pub fn to_bytes(&self) -> Vec<u8> {
        borsh::to_vec(self).expect("borsh serialization is infallible")
    }

    pub fn count(&self) -> usize {
        self.authors.len()
    }

    pub fn add(&mut self, author: [u8; 32], timestamp_ms: u64) -> Result<(), Error> {
        if self.authors.contains(&author) {
            return Err(Error::AlreadyPosted);
        }
        if self.authors.len() >= MAX_AUTHORS {
            return Err(Error::Full);
        }
        self.authors.push(author);
        if self.authors.len() == 1 || timestamp_ms < self.first_ms {
            self.first_ms = timestamp_ms;
        }
        self.last_ms = self.last_ms.max(timestamp_ms);
        let month = yyyymm(timestamp_ms);
        match self.monthly.binary_search_by_key(&month, |m| m.yyyymm) {
            Ok(i) => self.monthly[i].count += 1,
            Err(i) => self.monthly.insert(
                i,
                Month {
                    yyyymm: month,
                    count: 1,
                },
            ),
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn months_cross_year_and_leap_boundaries() {
        assert_eq!(yyyymm(0), 197_001);
        // 2024-02-29T23:59:59.999Z and the next millisecond.
        assert_eq!(yyyymm(1_709_251_199_999), 202_402);
        assert_eq!(yyyymm(1_709_251_200_000), 202_403);
        // 2026-12-31T23:59:59.999Z and 2027-01-01T00:00:00Z.
        assert_eq!(yyyymm(1_798_761_599_999), 202_612);
        assert_eq!(yyyymm(1_798_761_600_000), 202_701);
    }

    #[test]
    fn stats_count_each_author_once_and_tally_months() {
        let mut s = Stats::new("LP-0021/logos-kit".into());
        s.add([1; 32], 1_798_761_599_999).unwrap();
        s.add([2; 32], 1_798_761_600_000).unwrap();
        assert_eq!(s.add([1; 32], 1_798_761_600_001), Err(Error::AlreadyPosted));
        assert_eq!(s.count(), 2);
        assert_eq!(
            s.monthly,
            [
                Month { yyyymm: 202_612, count: 1 },
                Month { yyyymm: 202_701, count: 1 }
            ]
        );
        let full = Stats {
            authors: vec![[9; 32]; MAX_AUTHORS],
            ..Stats::new("x".into())
        };
        assert!(full.to_bytes().len() < 100 * 1024);
    }

    #[test]
    fn input_rules() {
        assert!(check_post("LP-0021/logos-kit", Some("abu"), "I use Logos Kit\nfor LEZ.").is_ok());
        assert_eq!(check_submission("has space"), Err(Error::Submission));
        assert_eq!(check_username(" abu"), Err(Error::Username));
        assert_eq!(check_text("   "), Err(Error::Text));
        assert_eq!(check_text("evil\u{202E}txt"), Err(Error::Text));
        assert_eq!(check_text(&"a".repeat(281)), Err(Error::Text));
        assert_eq!(window(60_000), Err(Error::Timestamp));
    }
}
