//! Payments into this wallet's public accounts, found by reading blocks.
//!
//! LEZ has no "transactions for this account" call on the sequencer (the
//! testnet runs no indexer), so the wallet reads the blocks itself: after
//! each sync it fetches the blocks since the last one it read and decodes
//! every transaction with the same decoders the approval sheet uses. A
//! public transaction counts when one of our accounts gains value and none
//! of ours pays (a send between two of our own accounts is already in the
//! activity as a send). A private transaction counts when its public effects
//! credit one of our accounts (a deshield from someone else's private
//! account; the sender stays hidden).
//!
//! Stage T moves this scan into `crates/chain-index` and adds token
//! accounts (ATAs) and tokens nobody told the wallet about.

use std::collections::HashSet;

use anyhow::{Context as _, Result};
use common::transaction::LeeTransaction;
use lee::AccountId;
use sequencer_service_rpc::{RpcClient as _, SequencerClient};
use serde::{Deserialize, Serialize};

use crate::decode::{self, Asset, Decoders, PublicEffect};

/// Blocks per `getBlockRange` call.
const CHUNK: u64 = 100;
/// Blocks read per sync, so a long gap is caught up over a few syncs instead
/// of holding one sync for minutes.
pub const STEP: u64 = 1_000;

/// One payment into one of our accounts.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Incoming {
    pub block: u64,
    pub timestamp_ms: u64,
    pub tx_hash: String,
    /// Our account that received it.
    pub account: String,
    /// The paying account; `None` when it came out of a private account.
    pub from: Option<String>,
    /// `None` = LGO; otherwise the token definition.
    pub token: Option<String>,
    pub amount: String,
}

/// Read blocks `from..=to` and return the payments into `mine`.
pub async fn scan(
    client: &SequencerClient,
    from: u64,
    to: u64,
    mine: &HashSet<AccountId>,
    decoders: &Decoders,
) -> Result<Vec<Incoming>> {
    let mut out = Vec::new();
    let mut start = from.max(1);
    while start <= to {
        let end = (start + CHUNK - 1).min(to);
        let blocks = client
            .get_block_range(start, end)
            .await
            .with_context(|| format!("blocks {start}..={end}"))?;
        for block in blocks {
            let id = block.header.block_id;
            // Block times are milliseconds; accept seconds too.
            let ts = block.header.timestamp;
            let timestamp_ms = if ts < 100_000_000_000 { ts * 1000 } else { ts };
            for tx in &block.body.transactions {
                let tx_hash = tx.hash().to_string();
                for (account, from, asset, amount) in credits(tx, mine, decoders) {
                    out.push(Incoming {
                        block: id,
                        timestamp_ms,
                        tx_hash: tx_hash.clone(),
                        account,
                        from,
                        token: match asset {
                            Asset::Native => None,
                            Asset::Token { definition, .. } => Some(definition),
                        },
                        amount: amount.to_string(),
                    });
                }
            }
        }
        start = end + 1;
    }
    Ok(out)
}

type Credit = (String, Option<String>, Asset, u128);

fn credits(tx: &LeeTransaction, mine: &HashSet<AccountId>, decoders: &Decoders) -> Vec<Credit> {
    let ours = |s: &str| {
        decode::account_id(s)
            .map(|id| mine.contains(&id))
            .unwrap_or(false)
    };
    match tx {
        LeeTransaction::Public(t) => {
            let summary = decode::public(t.message(), decoders);
            // Signed or paid by one of ours: it's our own send.
            let signed_by_us = t
                .witness_set()
                .signatures_and_public_keys()
                .iter()
                .any(|(_, pk)| mine.contains(&AccountId::from(pk)));
            if signed_by_us || summary.outflows.iter().any(|f| ours(&f.account)) {
                return Vec::new();
            }
            let payer = summary.outflows.first().map(|f| f.account.clone());
            summary
                .inflows
                .into_iter()
                .filter(|f| ours(&f.account) && f.amount > 0)
                .map(|f| (f.account, payer.clone(), f.asset, f.amount))
                .collect()
        }
        LeeTransaction::PrivacyPreserving(t) => {
            let signed_by_us = t
                .witness_set()
                .signatures_and_public_keys()
                .iter()
                .any(|(_, pk)| mine.contains(&AccountId::from(pk)));
            if signed_by_us {
                return Vec::new();
            }
            decode::private_effects(t.message())
                .into_iter()
                .filter_map(|e| match e {
                    PublicEffect::Credit {
                        account,
                        asset,
                        amount,
                    } if amount > 0 && ours(&account) => Some((account, None, asset, amount)),
                    _ => None,
                })
                .collect()
        }
    }
}
