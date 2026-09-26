//! Transactions: build, bind to an approval, (prove), re-check, sign, submit.
//!
//! The approval binds to a **request hash** (SHA-256 over a domain tag, the
//! chain, the requester, the intent and the exact message or the signer
//! nonces). The approving UI must echo it back, so a UI shown one request
//! can't approve another.
//!
//! At sign time the mutable inputs are fetched again: if a signer's nonce
//! moved, the approval is stale ([`Stale`]). A private transaction is proved
//! after approval; its proved message must touch exactly the approved public
//! accounts with the approved nonces before it is signed.

use std::str::FromStr as _;

use anyhow::{Context as _, Result, bail, ensure};
use lee::{
    AccountId, privacy_preserving_transaction::circuit::ProgramWithDependencies, program::Program,
};
use lee_core::native_token::{self, NATIVE_TOKEN_PROGRAM_ID, decode_balance};
use sequencer_service_rpc::RpcClient as _;
use serde::{Deserialize, Serialize};
use sha2::{Digest as _, Sha256};
use wallet::{
    AccDecodeData, AccountIdentity, ExecutionFailureKind, PreparedPrivateTx, PreparedPublicTx,
    ProvedPrivateTx, SelectedShard, WalletCore,
};

use crate::session::Session;

const HASH_DOMAIN: &[u8] = b"logos-kit/approval/v1\0";

/// What a caller asks the wallet to do. Amounts are native-token base units.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "camelCase")]
pub enum Intent {
    /// Public → public native transfer.
    Transfer {
        from: String,
        to: String,
        #[serde(with = "amount")]
        amount: u128,
    },
    /// Public → one of this wallet's private accounts (needs a proof).
    Shield {
        from: String,
        to: String,
        #[serde(with = "amount")]
        amount: u128,
    },
}

/// Amounts travel as decimal strings: JSON numbers lose precision past 2^53.
mod amount {
    use serde::{Deserialize as _, Deserializer, Serializer};

    pub fn serialize<S: Serializer>(v: &u128, s: S) -> Result<S::Ok, S::Error> {
        s.serialize_str(&v.to_string())
    }

    pub fn deserialize<'de, D: Deserializer<'de>>(d: D) -> Result<u128, D::Error> {
        String::deserialize(d)?
            .parse()
            .map_err(serde::de::Error::custom)
    }
}

impl Intent {
    pub const fn amount(&self) -> u128 {
        match self {
            Self::Transfer { amount, .. } | Self::Shield { amount, .. } => *amount,
        }
    }

    pub fn from_account(&self) -> &str {
        match self {
            Self::Transfer { from, .. } | Self::Shield { from, .. } => from,
        }
    }

    pub fn to_account(&self) -> &str {
        match self {
            Self::Transfer { to, .. } | Self::Shield { to, .. } => to,
        }
    }

    /// Needs a zero-knowledge proof (minutes on a desktop CPU).
    pub const fn is_private(&self) -> bool {
        matches!(self, Self::Shield { .. })
    }
}

/// The approval sheet's content: everything the user is agreeing to.
#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Review {
    pub chain: String,
    /// The app asking (module name), or `None` when the owner asked (CLI, wallet UI).
    pub requester: Option<String>,
    pub intent: Intent,
    /// The sender's balance now, for "balance after".
    #[serde(with = "amount")]
    pub from_balance: u128,
    pub fee: Fee,
    /// Hex; the approving UI echoes it back.
    pub request_hash: String,
}

#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Fee {
    /// Who pays (public transactions); private ones are fee-exempt in 0.3.
    pub payer: Option<String>,
    /// The cap the transaction reserves; the real fee is at most this.
    pub max_fee: Option<String>,
    pub gas_limit: Option<u64>,
    /// The sequencer's current execution base fee per gas (`getFeeState`),
    /// when it offers one. Gas used is only known after inclusion.
    pub base_fee_exec: Option<u64>,
}

/// Returned (inside `anyhow::Error`) when something changed since approval.
#[derive(Debug)]
pub struct Stale(pub String);

impl std::fmt::Display for Stale {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "changed since you approved: {}", self.0)
    }
}

impl std::error::Error for Stale {}

/// A built transaction waiting for approval. Holds no private keys.
pub struct Prepared {
    pub review: Review,
    hash: [u8; 32],
    signer: AccountId,
    signer_nonce: u128,
    body: Body,
}

enum Body {
    Public(PreparedPublicTx),
    Private {
        tx: Box<PreparedPrivateTx>,
        recipient: AccountId,
    },
}

/// Private body after proving, ready for the re-check and signature.
pub struct Proved {
    tx: ProvedPrivateTx,
    recipient: AccountId,
}

impl Prepared {
    pub const fn hash(&self) -> &[u8; 32] {
        &self.hash
    }

    pub const fn needs_proof(&self) -> bool {
        matches!(self.body, Body::Private { .. })
    }
}

fn account(id: &str) -> Result<AccountId> {
    AccountId::from_str(id).with_context(|| format!("not a LEZ account id: {id}"))
}

fn lez(e: ExecutionFailureKind) -> anyhow::Error {
    anyhow::anyhow!("{e}")
}

fn transfer_instruction(amount: u128) -> Result<lee_core::program::InstructionData> {
    Program::serialize_instruction(native_token::Instruction::Transfer { amount })
        .map_err(|e| anyhow::anyhow!("encode transfer: {e:?}"))
}

/// Same check LEZ's own transfer facade runs before building.
fn enough_balance(
    amount: u128,
) -> impl FnOnce(&[SelectedShard]) -> Result<(), ExecutionFailureKind> {
    move |shards: &[SelectedShard]| {
        let from = &shards[0];
        let balance = decode_balance(from.shard_of(NATIVE_TOKEN_PROGRAM_ID))
            .map_err(|_| ExecutionFailureKind::AccountDataError(from.selector.account_id))?;
        if balance >= amount {
            Ok(())
        } else {
            Err(ExecutionFailureKind::InsufficientFundsError)
        }
    }
}

fn request_hash(chain: &str, requester: Option<&str>, intent: &Intent, bound: &[u8]) -> [u8; 32] {
    let mut h = Sha256::new();
    h.update(HASH_DOMAIN);
    for part in [chain.as_bytes(), requester.unwrap_or("").as_bytes()] {
        h.update((part.len() as u64).to_le_bytes());
        h.update(part);
    }
    // Serialized with a fixed field order (serde derive), so it is canonical.
    let intent = serde_json::to_vec(intent).unwrap_or_default();
    h.update((intent.len() as u64).to_le_bytes());
    h.update(&intent);
    h.update(bound);
    h.finalize().into()
}

async fn nonce_of(core: &WalletCore, id: AccountId) -> Result<u128> {
    let nonces = core.get_accounts_nonces(&[id]).await?;
    Ok(nonces.first().context("sequencer returned no nonce")?.0)
}

/// Private native balance as synced into this wallet.
fn private_balance(core: &WalletCore, id: AccountId) -> Option<u128> {
    let account = core.get_account_private(id)?;
    decode_balance(account.data.shard(NATIVE_TOKEN_PROGRAM_ID)).ok()
}

impl Session {
    /// Build `intent` for approval (connects if needed). Checks funds, that
    /// the sender is ours, and for a shield that the recipient is our private account.
    pub async fn prepare(&mut self, requester: Option<&str>, intent: Intent) -> Result<Prepared> {
        let chain = self.zone().chain.clone();
        self.connect().await?;
        let core = self.core().context("not connected")?;
        let from = account(intent.from_account())?;
        let to = account(intent.to_account())?;
        ensure!(intent.amount() > 0, "amount must be more than zero");
        ensure!(
            core.get_account_public_signing_key(from).is_some(),
            "{from} is not a public account of this wallet"
        );
        let from_balance = core.get_account_balance(from).await?;
        let instruction = transfer_instruction(intent.amount())?;

        let (body, signer_nonce, bound, fee) = match &intent {
            Intent::Transfer { .. } => {
                ensure!(from != to, "sender and recipient are the same account");
                let tx = core
                    .prepare_public(
                        vec![
                            AccountIdentity::Public(from).balance(),
                            AccountIdentity::PublicNoSign(to).balance(),
                        ],
                        instruction,
                        NATIVE_TOKEN_PROGRAM_ID,
                        None,
                        enough_balance(intent.amount()),
                    )
                    .await
                    .map_err(lez)?;
                let message = tx.message();
                let fee = message.fee.as_ref().map_or(
                    Fee {
                        payer: None,
                        max_fee: None,
                        gas_limit: None,
                        base_fee_exec: None,
                    },
                    |f| Fee {
                        payer: Some(f.payer.to_string()),
                        max_fee: Some(f.max_fee.to_string()),
                        gas_limit: Some(f.gas_limit),
                        base_fee_exec: None,
                    },
                );
                if let Some(f) = message.fee.as_ref() {
                    if f.payer == from {
                        ensure!(
                            from_balance >= intent.amount().saturating_add(f.max_fee),
                            "not enough to cover {} plus a fee of up to {}",
                            intent.amount(),
                            f.max_fee
                        );
                    } else {
                        let payer = core.get_account_balance(f.payer).await?;
                        ensure!(
                            payer >= f.max_fee,
                            "fee payer {} can't cover a fee of up to {}",
                            f.payer,
                            f.max_fee
                        );
                    }
                }
                // The message commits to program, accounts, nonces, data and fee.
                let bound = message.hash().to_vec();
                let nonce = message
                    .nonces
                    .first()
                    .context("public tx without nonces")?
                    .0;
                (Body::Public(tx), nonce, bound, fee)
            }
            Intent::Shield { .. } => {
                let recipient = core
                    .resolve_private_account(to)
                    .with_context(|| format!("{to} is not a private account of this wallet"))?;
                let tx = core
                    .prepare_private(
                        vec![AccountIdentity::Public(from).balance(), recipient.balance()],
                        instruction,
                        &ProgramWithDependencies::native(),
                        enough_balance(intent.amount()),
                    )
                    .await
                    .map_err(lez)?;
                let nonce = nonce_of(core, from).await?;
                let fee = Fee {
                    payer: None,
                    max_fee: None,
                    gas_limit: None,
                    base_fee_exec: None,
                };
                (
                    Body::Private {
                        tx: Box::new(tx),
                        recipient: to,
                    },
                    nonce,
                    nonce.to_le_bytes().to_vec(),
                    fee,
                )
            }
        };

        let mut fee = fee;
        if fee.payer.is_some() {
            // Informational only: the approval binds to max_fee, not this.
            fee.base_fee_exec = core
                .helm_owned()
                .get_fee_state()
                .await
                .ok()
                .map(|q| q.base_fee_exec);
        }
        // Chain and zone id: two zones never share an approval.
        let scope = format!("{chain}|{}", self.zone().id);
        let hash = request_hash(&scope, requester, &intent, &bound);
        Ok(Prepared {
            review: Review {
                chain,
                requester: requester.map(str::to_owned),
                intent,
                from_balance,
                fee,
                request_hash: hex::encode(hash),
            },
            hash,
            signer: from,
            signer_nonce,
            body,
        })
    }

    /// Nothing the approval depends on moved (call right before signing).
    async fn recheck(&self, signer: AccountId, nonce: u128) -> Result<()> {
        let core = self.core().context("not connected")?;
        let now = nonce_of(core, signer).await?;
        if now != nonce {
            return Err(Stale(format!("{signer} nonce is {now}, approved at {nonce}")).into());
        }
        Ok(())
    }

    /// Sign and submit an approved public transaction. Returns the tx hash.
    pub async fn submit_public(&mut self, prepared: Prepared) -> Result<String> {
        let Prepared {
            signer,
            signer_nonce,
            body: Body::Public(tx),
            ..
        } = prepared
        else {
            bail!("this transaction needs a proof first");
        };
        self.recheck(signer, signer_nonce).await?;
        let core = self.core().context("not connected")?;
        let hash = core.sign_and_submit_public(tx).await.map_err(lez)?;
        Ok(hash.to_string())
    }

    /// Check the proof matches the approval, then sign and submit.
    pub async fn submit_proved(
        &mut self,
        signer: AccountId,
        signer_nonce: u128,
        proved: Proved,
    ) -> Result<String> {
        let message = proved.tx.message();
        let touched: Vec<AccountId> = message
            .public_actions
            .iter()
            .map(|a| a.account_id)
            .collect();
        if touched != [signer] || message.nonces.iter().map(|n| n.0).ne([signer_nonce]) {
            return Err(Stale(format!(
                "the proof touches {touched:?} with nonces {:?}; approved {signer} at {signer_nonce}",
                message.nonces
            ))
            .into());
        }
        self.recheck(signer, signer_nonce).await?;
        let core = self.core().context("not connected")?;
        let (hash, secrets) = core.sign_and_submit_private(proved.tx).await.map_err(lez)?;
        self.pending_note = Some((hash, secrets, proved.recipient));
        Ok(hash.to_string())
    }

    /// Wait until the transaction is in a block. For a private transaction
    /// sent from here, also record its note so the balance shows at once.
    /// Returns the block, plus a warning if that local bookkeeping failed
    /// (the transaction is included either way; the next sync repairs it).
    pub async fn wait_included(&mut self, tx_hash: &str) -> Result<(u64, Option<String>)> {
        let hash = tx_hash.parse().context("tx hash")?;
        let pending = self.pending_note.take();
        let core = self.core_mut().context("not connected")?;
        let (tx, block) = core.poll_transaction(hash).await?;
        let mut warning = None;
        if let (common::transaction::LeeTransaction::PrivacyPreserving(tx), Some((h, secrets, to))) =
            (&tx, pending)
            && h == hash
        {
            let mask: Vec<AccDecodeData> = secrets
                .into_iter()
                .take(1)
                .map(|s| AccDecodeData::Decode(s, to))
                .collect();
            if let Err(e) = core.decode_insert_privacy_preserving_transaction_results(tx, &mask) {
                warning = Some(format!(
                    "included; note not recorded yet ({e:#}); sync to see it"
                ));
            }
        }
        if let Err(e) = self.persist_now() {
            warning = Some(format!("included; saving the wallet failed ({e:#})"));
        }
        Ok((block, warning))
    }

    /// Native balance of one of this wallet's accounts (public: from the
    /// sequencer; private: as synced).
    pub async fn balance(&mut self, account_id: &str) -> Result<u128> {
        self.connect().await?;
        let id = account(account_id)?;
        let core = self.core().context("not connected")?;
        if core.get_account_public_signing_key(id).is_some() {
            return core.get_account_balance(id).await;
        }
        private_balance(core, id).with_context(|| format!("{id} is not an account of this wallet"))
    }
}

impl Prepared {
    /// Split off the proving work (runs without the session: CPU only).
    pub fn into_proving(self) -> Result<(ProvingJob, Review, AccountId, u128)> {
        match self.body {
            Body::Private { tx, recipient } => Ok((
                ProvingJob { tx, recipient },
                self.review,
                self.signer,
                self.signer_nonce,
            )),
            Body::Public(_) => bail!("a public transaction has nothing to prove"),
        }
    }
}

/// The proving half of a private transaction. `run` blocks for minutes.
pub struct ProvingJob {
    tx: Box<PreparedPrivateTx>,
    recipient: AccountId,
}

impl ProvingJob {
    pub fn run(self) -> Result<Proved> {
        let tx = self.tx.prove().map_err(lez)?;
        Ok(Proved {
            tx,
            recipient: self.recipient,
        })
    }
}
