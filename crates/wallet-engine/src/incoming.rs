//! Payments into this wallet's public accounts and their token accounts,
//! found by reading blocks (`chain-index`).
//!
//! After each sync the wallet reads the blocks since its saved position and
//! decodes every transaction with the same decoders the approval sheet uses.
//! A public transaction counts when value lands in one of our accounts, or in
//! the associated token account (ATA) of one of our accounts for any token,
//! and none of ours pays (a send between our own accounts is already in the
//! activity as a send). A private transaction counts when its public effects
//! credit one of those (a deshield from someone else's private account; the
//! sender stays hidden). Every token that lands this way is also reported, so
//! the wallet knows about tokens nobody told it about.

use std::collections::HashSet;

use anyhow::Result;
use chain_index::{Cursor, Scanner, Step, block_time_ms};
use common::transaction::LeeTransaction;
use lee::AccountId;
use sequencer_service_rpc::SequencerClient;
use serde::{Deserialize, Serialize};

use crate::decode::{self, Asset, Decoders, PublicEffect};

/// Blocks read per sync, so a long gap is caught up over a few syncs instead
/// of holding one sync for minutes.
pub const STEP: u64 = 1_000;

/// One payment into one of our accounts (or its token account).
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Incoming {
    pub block: u64,
    pub timestamp_ms: u64,
    pub tx_hash: String,
    /// Our account that received it (the owner, for a token account).
    pub account: String,
    /// Where it landed when that isn't `account` itself (its ATA).
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub holder: Option<String>,
    /// The paying account; `None` when it came out of a private account.
    pub from: Option<String>,
    /// `None` = LGO; otherwise the token definition.
    pub token: Option<String>,
    pub amount: String,
}

/// Read up to [`STEP`] blocks after `cursor` and return the payments into
/// `mine`, the new cursor and what the scanner did.
pub async fn scan(
    client: &SequencerClient,
    cursor: &Cursor,
    mine: &HashSet<AccountId>,
    decoders: &Decoders,
) -> Result<(Vec<Incoming>, Cursor, Step)> {
    let mut out = Vec::new();
    let (next, step) = Scanner::new(client)
        .advance(cursor, STEP, |block| {
            let id = block.header.block_id;
            let timestamp_ms = block_time_ms(block);
            for tx in &block.body.transactions {
                let tx_hash = tx.hash().to_string();
                for c in credits(tx, mine, decoders) {
                    out.push(Incoming {
                        block: id,
                        timestamp_ms,
                        tx_hash: tx_hash.clone(),
                        account: c.owner.to_string(),
                        holder: (c.holder != c.owner).then(|| c.holder.to_string()),
                        from: c.from,
                        token: match c.asset {
                            Asset::Native => None,
                            Asset::Token { definition, .. } => Some(definition),
                        },
                        amount: c.amount.to_string(),
                    });
                }
            }
        })
        .await?;
    Ok((out, next, step))
}

struct Credit {
    owner: AccountId,
    holder: AccountId,
    from: Option<String>,
    asset: Asset,
    amount: u128,
}

/// Which of our accounts `account` is: one of them, or the ATA of one of
/// them for `asset`'s token.
fn owner_of(
    account: &str,
    asset: &Asset,
    mine: &HashSet<AccountId>,
) -> Option<(AccountId, AccountId)> {
    let id = decode::account_id(account).ok()?;
    if mine.contains(&id) {
        return Some((id, id));
    }
    let Asset::Token { definition, .. } = asset else {
        return None;
    };
    let def = decode::account_id(definition).ok()?;
    mine.iter()
        .find(|own| crate::tokens::ata_of(**own, def) == id)
        .map(|own| (*own, id))
}

fn credits(tx: &LeeTransaction, mine: &HashSet<AccountId>, decoders: &Decoders) -> Vec<Credit> {
    let signed_by_us = |keys: &[(lee::Signature, lee::PublicKey)]| {
        keys.iter()
            .any(|(_, pk)| mine.contains(&AccountId::from(pk)))
    };
    match tx {
        LeeTransaction::Public(t) => {
            // Signed by one of ours: it's our own send.
            if signed_by_us(t.witness_set().signatures_and_public_keys()) {
                return Vec::new();
            }
            let summary = decode::public(t.message(), decoders);
            if summary
                .outflows
                .iter()
                .any(|f| owner_of(&f.account, &f.asset, mine).is_some())
            {
                return Vec::new();
            }
            let payer = summary.outflows.first().map(|f| f.account.clone());
            summary
                .inflows
                .into_iter()
                .filter(|f| f.amount > 0)
                .filter_map(|f| {
                    let (owner, holder) = owner_of(&f.account, &f.asset, mine)?;
                    Some(Credit {
                        owner,
                        holder,
                        from: payer.clone(),
                        asset: f.asset,
                        amount: f.amount,
                    })
                })
                .collect()
        }
        LeeTransaction::PrivacyPreserving(t) => {
            if signed_by_us(t.witness_set().signatures_and_public_keys()) {
                return Vec::new();
            }
            decode::private_effects(t.message())
                .into_iter()
                .filter_map(|e| match e {
                    PublicEffect::Credit {
                        account,
                        asset,
                        amount,
                    } if amount > 0 => {
                        let (owner, holder) = owner_of(&account, &asset, mine)?;
                        Some(Credit {
                            owner,
                            holder,
                            from: None,
                            asset,
                            amount,
                        })
                    }
                    _ => None,
                })
                .collect()
        }
    }
}
