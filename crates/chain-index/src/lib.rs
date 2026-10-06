//! Reading LEZ blocks in order, from a saved position.
//!
//! LEZ has no "transactions for this account" call on the sequencer, and the
//! public testnet runs no indexer, so everything Logos Kit needs to know
//! about the chain (payments into the wallet, tokens nobody told it about,
//! later NFTs, membership-proof roots and Market listings) comes from reading
//! the blocks themselves. This crate owns the reading; each consumer decides
//! what a block means to it.
//!
//! A [`Cursor`] says how far a consumer has read: blocks `1..=block`, the
//! last one with `hash`. [`Scanner::advance`] reads the next blocks (at most
//! `max`, so a long gap is caught up over several calls instead of one long
//! one) and hands each to a visitor in order. Before reading, it checks that
//! the block under the cursor still has the same hash; if not, the chain was
//! reset (testnets are) and the consumer starts over.

use anyhow::{Context as _, Result, ensure};
use common::block::Block;
use sequencer_service_rpc::{RpcClient as _, SequencerClient};
use serde::{Deserialize, Serialize};

/// Blocks per `getBlockRange` call.
pub const CHUNK: u64 = 100;

/// How far a consumer has read.
#[derive(Clone, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Cursor {
    /// Blocks `1..=block` have been read (0: none).
    pub block: u64,
    /// That block's hash, to notice a reset chain (`None`: not recorded).
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub hash: Option<String>,
}

impl Cursor {
    /// Nothing before `block` matters (a new wallet starts at today's tip).
    pub const fn at(block: u64, hash: Option<String>) -> Self {
        Self { block, hash }
    }
}

/// What one [`Scanner::advance`] did.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Step {
    /// Read `from..=to`; the chain's tip was `tip`.
    Read { from: u64, to: u64, tip: u64 },
    /// Nothing new.
    UpToDate { tip: u64 },
    /// The block under the cursor is different: start over from 0.
    Reset { tip: u64 },
}

impl Step {
    /// Blocks still unread after this step (for a progress line).
    pub const fn behind(&self) -> u64 {
        match self {
            Self::Read { to, tip, .. } => tip.saturating_sub(*to),
            Self::UpToDate { .. } => 0,
            Self::Reset { tip } => *tip,
        }
    }
}

/// Reads blocks from one sequencer.
pub struct Scanner<'a> {
    client: &'a SequencerClient,
}

impl<'a> Scanner<'a> {
    pub const fn new(client: &'a SequencerClient) -> Self {
        Self { client }
    }

    /// The chain's latest block.
    pub async fn tip(&self) -> Result<u64> {
        self.client
            .get_last_block_id()
            .await
            .context("latest block")
    }

    /// Read up to `max` blocks after `cursor` and give each to `visit`, in
    /// order. Returns the new cursor and what happened. `visit` sees a block
    /// only once per successful call; on an error part-way, the cursor isn't
    /// moved, so the next call reads those blocks again (visitors must
    /// tolerate seeing a block twice).
    pub async fn advance(
        &self,
        cursor: &Cursor,
        max: u64,
        mut visit: impl FnMut(&Block),
    ) -> Result<(Cursor, Step)> {
        let tip = self.tip().await?;
        // A node behind us (a lagging replica, or a reset chain still
        // shorter than what we read) means wait; only a different block
        // under the cursor means the chain was reset.
        if cursor.block > tip {
            return Ok((cursor.clone(), Step::UpToDate { tip }));
        }
        if !self.still_there(cursor).await? {
            return Ok((Cursor::default(), Step::Reset { tip }));
        }
        if cursor.block == tip {
            return Ok((cursor.clone(), Step::UpToDate { tip }));
        }
        let from = cursor.block + 1;
        let to = tip.min(cursor.block.saturating_add(max.max(1)));
        let mut last_hash = cursor.hash.clone();
        let mut start = from;
        let mut blocks = Vec::new();
        while start <= to {
            let end = (start + CHUNK - 1).min(to);
            let chunk = self
                .client
                .get_block_range(start, end)
                .await
                .with_context(|| format!("blocks {start}..={end}"))?;
            blocks.extend(chunk);
            start = end + 1;
        }
        // Every block, in order, each on top of the one before: a short
        // reply is retried next time (never skipped), a fork is a reset.
        ensure!(
            blocks.len() as u64 == to - from + 1,
            "blocks {from}..={to}: the node returned {} of {}",
            blocks.len(),
            to - from + 1
        );
        for (expected, block) in (from..=to).zip(&blocks) {
            ensure!(
                block.header.block_id == expected,
                "asked for block {expected}, got {}",
                block.header.block_id
            );
            if last_hash
                .as_deref()
                .is_some_and(|h| h != block.header.prev_block_hash.to_string())
            {
                return Ok((Cursor::default(), Step::Reset { tip }));
            }
            last_hash = Some(block.header.hash.to_string());
        }
        blocks.iter().for_each(&mut visit);
        Ok((Cursor::at(to, last_hash), Step::Read { from, to, tip }))
    }

    /// The cursor just before the first block made at or after `ms` (unix
    /// milliseconds): where a wallet created at `ms` starts reading, so
    /// nothing sent to it after that is missed. Binary search on block times
    /// (about 14 reads for 10,000 blocks).
    pub async fn cursor_before_time(&self, ms: u64) -> Result<Cursor> {
        let tip = self.tip().await?;
        let (mut lo, mut hi) = (1u64, tip);
        if tip == 0 {
            return Ok(Cursor::default());
        }
        while lo < hi {
            let mid = lo + (hi - lo) / 2;
            match self
                .client
                .get_block(mid)
                .await
                .with_context(|| format!("block {mid}"))?
            {
                Some(b) if block_time_ms(&b) >= ms => hi = mid,
                _ => lo = mid + 1,
            }
        }
        let start = lo.saturating_sub(1);
        let hash = match start {
            0 => None,
            n => self
                .client
                .get_block(n)
                .await?
                .map(|b| b.header.hash.to_string()),
        };
        Ok(Cursor::at(start, hash))
    }

    /// The block under the cursor still has the hash we recorded.
    async fn still_there(&self, cursor: &Cursor) -> Result<bool> {
        let (Some(hash), true) = (&cursor.hash, cursor.block > 0) else {
            return Ok(true);
        };
        let block = self
            .client
            .get_block(cursor.block)
            .await
            .with_context(|| format!("block {}", cursor.block))?;
        // A node without the block can't say it changed.
        Ok(block.is_none_or(|b| b.header.hash.to_string() == *hash))
    }
}

/// A block's time in unix milliseconds (LEZ block times are milliseconds;
/// seconds are accepted too).
pub const fn block_time_ms(block: &Block) -> u64 {
    let ts = block.header.timestamp;
    if ts < 100_000_000_000 { ts * 1000 } else { ts }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn cursor_round_trips_and_defaults() {
        let c = Cursor::at(42, Some("ab".into()));
        let v = serde_json::to_value(&c).unwrap();
        assert_eq!(v, serde_json::json!({ "block": 42, "hash": "ab" }));
        let back: Cursor = serde_json::from_value(serde_json::json!({ "block": 7 })).unwrap();
        assert_eq!(back, Cursor::at(7, None));
        assert_eq!(
            Step::Read {
                from: 1,
                to: 10,
                tip: 25
            }
            .behind(),
            15
        );
    }
}
