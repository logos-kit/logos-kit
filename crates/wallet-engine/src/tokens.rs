//! Token holdings.
//!
//! In 0.3 every account has one shard per program, so an account's own
//! token shard holds at most one token. Other tokens sit in associated token
//! accounts (ATAs): PDAs of the ATA program keyed by (owner, definition).
//! Holdings are therefore found in two places: each of our accounts' token
//! shard (public: live; private: as synced), and the ATA of each of our
//! public accounts for every token this wallet tracks in the zone.

use anyhow::{Context as _, Result};
use associated_token_account_core::{compute_ata_seed, get_associated_token_account_id};
use lee::{AccountId, ProgramShardSelector};
use serde::Serialize;
use token_core::{TokenDefinition, TokenHolding, TokenKind};
use wallet::WalletCore;

use crate::{
    decode,
    session::{AccountKind, Session},
    tx::{amount, holding_amount, own_shard},
};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum Via {
    /// The account's own token shard.
    Account,
    /// Its associated token account.
    Ata,
}

#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Holding {
    /// Our account (the owner, for an ATA).
    pub account: String,
    pub private: bool,
    pub via: Via,
    /// Where the tokens sit (the ATA address, or the account itself).
    pub holder: String,
    pub definition: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub name: Option<String>,
    pub kind: &'static str,
    #[serde(with = "amount")]
    pub amount: u128,
}

const fn kind_name(k: TokenKind) -> &'static str {
    match k {
        TokenKind::Fungible => "fungible",
        TokenKind::NftMaster => "nft_master",
        TokenKind::NftPrintedCopy => "nft_copy",
    }
}

/// The ATA address of `owner` for `definition` under the builtin programs.
pub fn ata_of(owner: AccountId, definition: AccountId) -> AccountId {
    get_associated_token_account_id(
        &programs::ata_account_id(),
        &compute_ata_seed(owner, definition, programs::token_account_id()),
    )
}

/// A token definition's name, read from its definition account.
pub async fn definition_name(core: &WalletCore, definition: AccountId) -> Option<String> {
    let token = programs::token_account_id();
    let account = core
        .get_account_view(ProgramShardSelector::new(definition, token))
        .await
        .ok()?;
    match borsh::from_slice::<TokenDefinition>(account.data.shard(token).as_ref()).ok()? {
        TokenDefinition::Fungible { name, .. } | TokenDefinition::NonFungible { name, .. } => {
            Some(name)
        }
    }
}

async fn public_holding(core: &WalletCore, id: AccountId) -> Result<Option<TokenHolding>> {
    let token = programs::token_account_id();
    let account = core
        .get_account_view(ProgramShardSelector::new(id, token))
        .await?;
    let shard = account.data.shard(token);
    if shard.is_empty() {
        return Ok(None);
    }
    Ok(borsh::from_slice(shard.as_ref()).ok())
}

impl Session {
    /// Every token this wallet holds in the current zone.
    pub async fn holdings(&mut self) -> Result<Vec<Holding>> {
        self.connect().await?;
        let accounts = self.accounts()?;
        let tracked: Vec<AccountId> = self
            .tracked_tokens()
            .iter()
            .filter_map(|t| decode::account_id(t).ok())
            .collect();
        let core = self.core().context("not connected")?;
        let token = programs::token_account_id();
        let mut out = Vec::new();
        for a in &accounts {
            let id = decode::account_id(&a.account_id)?;
            let private = a.kind == AccountKind::Private;
            let own = if private {
                own_shard(core, id, true, token)
                    .await
                    .ok()
                    .and_then(|b| borsh::from_slice::<TokenHolding>(&b).ok())
            } else {
                public_holding(core, id).await?
            };
            if let Some(h) = own {
                out.push((a.account_id.clone(), private, Via::Account, id, h));
            }
            if private {
                continue;
            }
            for def in &tracked {
                let ata = ata_of(id, *def);
                if let Some(h) = public_holding(core, ata).await? {
                    out.push((a.account_id.clone(), false, Via::Ata, ata, h));
                }
            }
        }
        let mut holdings = Vec::with_capacity(out.len());
        for (account, private, via, holder, h) in out {
            holdings.push(Holding {
                account,
                private,
                via,
                holder: holder.to_string(),
                definition: h.definition_id().to_string(),
                name: definition_name(core, h.definition_id()).await,
                kind: kind_name(h.kind()),
                amount: holding_amount(&h),
            });
        }
        Ok(holdings)
    }
}

/// A `Call` creating a fungible token: `definition` (a fresh public account
/// of ours) becomes its definition, and all `supply` goes to `holder`.
pub fn create_token_intent(
    holder: &str,
    definition: &str,
    name: &str,
    supply: u128,
) -> Result<crate::tx::Intent> {
    use base64::{Engine as _, engine::general_purpose::STANDARD};
    anyhow::ensure!(
        !name.is_empty() && name.len() <= 32,
        "token name must be 1–32 bytes"
    );
    let data = borsh::to_vec(&token_core::Instruction::NewFungibleDefinition {
        name: name.to_owned(),
        total_supply: supply,
    })?;
    let signer = |account: &str| crate::tx::CallAccount {
        account: account.to_owned(),
        shard: None,
        signer: true,
    };
    Ok(crate::tx::Intent::Call {
        from: holder.to_owned(),
        program: programs::token_account_id().to_string(),
        accounts: vec![signer(definition), signer(holder)],
        data: STANDARD.encode(data),
    })
}
