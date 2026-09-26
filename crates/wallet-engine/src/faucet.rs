//! Testnet funds behind one trait, so the mini-app never changes when the
//! source does.
//!
//! LEZ 0.3 ships no faucet (no piñata program; `lez-faucet-ffi` and
//! `FaucetMint` target 0.2), so which backend a zone uses is decided on
//! launch day (PLAN.md S4 decision tree). The backends here:
//!
//! - [`KeyFaucet`]: sends native tokens from a funded key it holds, with a
//!   per-account rate limit and idempotent request keys. With a debug
//!   genesis key it is the e2e/demo `GenesisSupply`; behind HTTP it is the
//!   disclosed self-hostable drip service.
//! - [`HttpFaucet`]: a client for that drip service.
//!
//! Outcomes follow `lez-faucet-ffi`'s `classify()`: `funded` only when the
//! target's balance moved by exactly the drop; anything unproven is
//! `outcome_unknown`, never retried blindly (a retry could pay twice).

use std::{
    collections::HashMap,
    sync::Mutex,
    time::{Duration, Instant},
};

use anyhow::{Context as _, Result, ensure};
use lee::{
    AccountId, FeeDeclaration, PrivateKey, ProgramShardSelector, PublicKey,
    public_transaction::{Message, PublicTransaction, WitnessSet},
};
use lee_core::native_token::{self, NATIVE_TOKEN_PROGRAM_ID};
use sequencer_service_rpc::{RpcClient as _, SequencerClient, SequencerClientBuilder};
use serde::{Deserialize, Serialize};

use crate::tx::amount;

/// `lez_requestFunds` result (protocol `RequestFundsResult`).
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "status", rename_all = "snake_case")]
pub enum FundOutcome {
    #[serde(rename_all = "camelCase")]
    Funded {
        #[serde(with = "amount")]
        amount: u128,
        tx_hash: String,
    },
    #[serde(rename_all = "camelCase")]
    RateLimited {
        retry_after_seconds: u64,
    },
    Rejected {
        reason: String,
    },
    #[serde(rename_all = "camelCase")]
    OutcomeUnknown {
        reason: String,
        #[serde(default, skip_serializing_if = "Option::is_none")]
        tx_hash: Option<String>,
    },
}

/// A source of testnet funds for a public account.
pub trait FaucetBackend: Send + Sync {
    /// Human name for the UI ("Local genesis supply", "Logos Kit drip").
    fn name(&self) -> &str;

    /// Fund `account`. `request_key` makes retries idempotent: the same key
    /// for the same account returns the first outcome instead of paying again.
    fn fund(
        &self,
        account: AccountId,
        request_key: &str,
    ) -> impl Future<Output = Result<FundOutcome>> + Send;
}

struct Ledger {
    last: HashMap<AccountId, Instant>,
    outcomes: HashMap<String, (AccountId, FundOutcome)>,
    busy: bool,
}

/// Funds from a key this process holds.
pub struct KeyFaucet {
    name: String,
    client: SequencerClient,
    key: PrivateKey,
    treasury: AccountId,
    drop: u128,
    every: Duration,
    gas_limit: u64,
    wait: Duration,
    ledger: Mutex<Ledger>,
}

impl KeyFaucet {
    /// `key_hex`: the treasury's private key. `drop`: base units per claim.
    /// `every`: how often one account may claim.
    pub fn new(
        name: &str,
        sequencer: &str,
        key_hex: &str,
        drop: u128,
        every: Duration,
    ) -> Result<Self> {
        let key: PrivateKey = key_hex
            .trim()
            .parse()
            .map_err(|e| anyhow::anyhow!("faucet key: {e:?}"))?;
        let treasury = AccountId::from(&PublicKey::new_from_private_key(&key));
        ensure!(drop > 0, "the faucet drop must be more than zero");
        Ok(Self {
            name: name.to_owned(),
            client: SequencerClientBuilder::default()
                .build(sequencer)
                .context("sequencer url")?,
            key,
            treasury,
            drop,
            every,
            gas_limit: wallet::DEFAULT_GAS_LIMIT,
            wait: Duration::from_secs(120),
            ledger: Mutex::new(Ledger {
                last: HashMap::new(),
                outcomes: HashMap::new(),
                busy: false,
            }),
        })
    }

    pub const fn treasury(&self) -> AccountId {
        self.treasury
    }

    fn ledger(&self) -> std::sync::MutexGuard<'_, Ledger> {
        self.ledger
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner)
    }

    async fn balance(&self, id: AccountId) -> Result<u128> {
        let account = self
            .client
            .get_account_view(ProgramShardSelector::native_balance(id))
            .await?;
        native_token::decode_balance(account.data.shard(NATIVE_TOKEN_PROGRAM_ID))
            .map_err(|e| anyhow::anyhow!("{e}"))
    }

    async fn pay(&self, to: AccountId) -> Result<FundOutcome> {
        let before = self.balance(to).await?;
        let nonce = self
            .client
            .get_accounts_nonces(vec![self.treasury])
            .await?
            .into_iter()
            .next()
            .context("no treasury nonce")?;
        let max_fee = wallet::max_fee_for(self.gas_limit);
        let reserve = self.balance(self.treasury).await?;
        if reserve < self.drop.saturating_add(max_fee) {
            return Ok(FundOutcome::Rejected {
                reason: "the faucet is empty".to_owned(),
            });
        }
        let message = Message::try_new_with_fees(
            NATIVE_TOKEN_PROGRAM_ID,
            vec![
                ProgramShardSelector::native_balance(self.treasury),
                ProgramShardSelector::native_balance(to),
            ],
            vec![nonce],
            native_token::Instruction::Transfer { amount: self.drop },
            FeeDeclaration::new(self.treasury, self.gas_limit, 0, max_fee),
        )
        .map_err(|e| anyhow::anyhow!("{e}"))?;
        let witness = WitnessSet::for_message(&message, &[&self.key]);
        let tx = PublicTransaction::new(message, witness);
        let hash = self
            .client
            .send_transaction(common::transaction::LeeTransaction::Public(tx))
            .await?;
        let tx_hash = hash.to_string();

        // Poll with backoff until included, then attribute by balance.
        let started = Instant::now();
        let mut delay = Duration::from_millis(500);
        while started.elapsed() < self.wait {
            tokio::time::sleep(delay).await;
            delay = (delay * 2).min(Duration::from_secs(5));
            if self
                .client
                .get_transaction(hash)
                .await
                .ok()
                .flatten()
                .is_none()
            {
                continue;
            }
            return Ok(match self.balance(to).await {
                Ok(now) if Some(now) == before.checked_add(self.drop) => FundOutcome::Funded {
                    amount: self.drop,
                    tx_hash,
                },
                Ok(_) => FundOutcome::OutcomeUnknown {
                    reason: "included, but the balance moved by another amount".to_owned(),
                    tx_hash: Some(tx_hash),
                },
                Err(e) => FundOutcome::OutcomeUnknown {
                    reason: format!("included; balance unreadable ({e})"),
                    tx_hash: Some(tx_hash),
                },
            });
        }
        Ok(FundOutcome::OutcomeUnknown {
            reason: "sent, not seen in a block yet".to_owned(),
            tx_hash: Some(tx_hash),
        })
    }
}

impl FaucetBackend for KeyFaucet {
    fn name(&self) -> &str {
        &self.name
    }

    async fn fund(&self, account: AccountId, request_key: &str) -> Result<FundOutcome> {
        ensure!(
            !request_key.is_empty() && request_key.len() <= 64,
            "request key must be 1–64 characters"
        );
        {
            let mut ledger = self.ledger();
            if let Some((to, outcome)) = ledger.outcomes.get(request_key) {
                return Ok(if *to == account {
                    outcome.clone()
                } else {
                    FundOutcome::Rejected {
                        reason: "this request key was used for another account".to_owned(),
                    }
                });
            }
            if let Some(at) = ledger.last.get(&account)
                && at.elapsed() < self.every
            {
                return Ok(FundOutcome::RateLimited {
                    retry_after_seconds: (self.every - at.elapsed()).as_secs().max(1),
                });
            }
            if account == self.treasury {
                return Ok(FundOutcome::Rejected {
                    reason: "that is the faucet's own account".to_owned(),
                });
            }
            // One drop in flight: the treasury nonce is used once at a time.
            if ledger.busy {
                return Ok(FundOutcome::RateLimited {
                    retry_after_seconds: 5,
                });
            }
            ledger.busy = true;
            ledger.last.insert(account, Instant::now());
        }
        let result = self.pay(account).await;
        let mut ledger = self.ledger();
        ledger.busy = false;
        match &result {
            Ok(outcome) => {
                if matches!(outcome, FundOutcome::Rejected { .. }) {
                    ledger.last.remove(&account);
                }
                ledger
                    .outcomes
                    .insert(request_key.to_owned(), (account, outcome.clone()));
            }
            // Nothing was sent (the error came before or at submission).
            Err(_) => {
                ledger.last.remove(&account);
            }
        }
        result
    }
}

/// Client for the drip service: `POST {base}/fund {"account","requestKey"}`
/// → a [`FundOutcome`] JSON body.
pub struct HttpFaucet {
    name: String,
    base: String,
}

impl HttpFaucet {
    pub fn new(name: &str, base: &str) -> Result<Self> {
        ensure!(
            base.starts_with("https://") || base.starts_with("http://127.0.0.1"),
            "the faucet must be https (or loopback for tests)"
        );
        Ok(Self {
            name: name.to_owned(),
            base: base.trim_end_matches('/').to_owned(),
        })
    }
}

impl FaucetBackend for HttpFaucet {
    fn name(&self) -> &str {
        &self.name
    }

    async fn fund(&self, account: AccountId, request_key: &str) -> Result<FundOutcome> {
        let url = format!("{}/fund", self.base);
        let body = serde_json::json!({ "account": account.to_string(), "requestKey": request_key });
        tokio::task::spawn_blocking(move || -> Result<FundOutcome> {
            let agent = ureq::Agent::config_builder()
                .timeout_global(Some(Duration::from_secs(180)))
                .http_status_as_error(false)
                .build()
                .new_agent();
            let mut resp = agent.post(&url).send_json(body)?;
            let outcome: FundOutcome = resp
                .body_mut()
                .with_config()
                .limit(64 * 1024)
                .read_json()
                .context("faucet reply")?;
            Ok(outcome)
        })
        .await?
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn outcomes_match_the_protocol_shape() {
        let v = serde_json::to_value(FundOutcome::RateLimited {
            retry_after_seconds: 30,
        })
        .unwrap();
        assert_eq!(v["status"], "rate_limited");
        assert_eq!(v["retryAfterSeconds"], 30);
        let v = serde_json::to_value(FundOutcome::Funded {
            amount: 5,
            tx_hash: "ab".into(),
        })
        .unwrap();
        assert_eq!(v["amount"], "5");
    }
}
