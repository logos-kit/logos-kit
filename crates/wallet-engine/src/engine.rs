//! The engine a host embeds: the unlocked wallet (behind auto-lock), the one
//! pending request, and transaction statuses. Every entry point takes the
//! [`Caller`] the host observed and applies the policy in `policy.rs`.
//!
//! Approval hardening (all `ui_qml` code shares one process, so a module name
//! alone could be impersonated):
//! - only one request is pending at a time; a second one is refused;
//! - approving echoes the request hash, and a mismatch cancels the request;
//! - the pending request is taken out atomically, so it is used at most once;
//! - private spends, large amounts and connects need the password again;
//! - it expires at its deadline, on a zone switch, lock, or restart (memory only).
//!
//! Proving runs on a blocking worker *without* the wallet lock, so status
//! reads (and the auto-lock timer) keep working for the minutes it takes.

use std::{
    collections::HashMap,
    sync::Mutex,
    time::{Duration, Instant, SystemTime, UNIX_EPOCH},
};

use anyhow::{Context as _, Result};
use base64::{Engine as _, engine::general_purpose::URL_SAFE_NO_PAD};
use chacha20poly1305::aead::{OsRng, rand_core::RngCore as _};
use serde::Serialize;

use crate::{
    auto_lock::AutoLock,
    policy::{self, Caller, Capability, Code, Denied, Grant},
    session::Session,
    tx::{Intent, Prepared, Review},
};

/// How long a request waits for the user.
pub const REQUEST_TTL: Duration = Duration::from_secs(5 * 60);

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum Lifecycle {
    AwaitingApproval,
    Building,
    Proving,
    Signing,
    Submitted,
    Included,
    Rejected,
    Dropped,
    Expired,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "lowercase")]
pub enum Outcome {
    Success,
    Failure,
    Unknown,
}

/// Where `outcome` comes from. Only an event or a check on our own account
/// counts; otherwise the outcome stays unknown.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "kebab-case")]
pub enum OutcomeSource {
    OwnAccountInvariant,
    None,
}

/// `lez_getTransactionStatus` result (plus `error` for the wallet's own UI).
#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct TxStatus {
    pub handle: String,
    pub chain: String,
    pub lifecycle: Lifecycle,
    pub outcome: Outcome,
    pub outcome_source: OutcomeSource,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub tx_hash: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub block: Option<u64>,
    /// When the current phase began (unix ms), for elapsed timers.
    pub phase_started_ms: u64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
    #[serde(skip)]
    requester: Option<String>,
}

/// What `request_*` hands the approving UI.
#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Ticket {
    pub handle: String,
    pub request: RequestView,
    /// The approval must carry the password (private spend, large amount, connect).
    pub needs_password: bool,
    pub expires_in_ms: u64,
}

#[derive(Clone, Debug, Serialize)]
#[serde(tag = "type", rename_all = "camelCase")]
pub enum RequestView {
    Transaction(Review),
    #[serde(rename_all = "camelCase")]
    Connect {
        requester: String,
        chain: String,
        accounts: Vec<String>,
        capabilities: Vec<Capability>,
        request_hash: String,
    },
}

enum Kind {
    Tx(Box<Prepared>),
    Connect {
        requester: String,
        accounts: Vec<String>,
        capabilities: Vec<Capability>,
    },
}

struct Pending {
    handle: String,
    requester: Option<String>,
    kind: Kind,
    hash: [u8; 32],
    needs_password: bool,
    deadline: Instant,
}

#[derive(Default)]
struct State {
    pending: Option<Pending>,
    statuses: HashMap<String, TxStatus>,
    /// Handle of the transaction being proved (one prover slot).
    proving: Option<String>,
    cancelled: Vec<String>,
}

pub struct Config {
    /// Amounts at or above this need the password again (base units).
    pub reauth_at: u128,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            reauth_at: 1_000_000,
        }
    }
}

pub struct Engine {
    wallet: tokio::sync::Mutex<AutoLock>,
    state: Mutex<State>,
    config: Config,
}

fn now_ms() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_or(0, |d| u64::try_from(d.as_millis()).unwrap_or(u64::MAX))
}

fn new_handle() -> String {
    let mut bytes = [0_u8; 18];
    OsRng.fill_bytes(&mut bytes);
    format!("lk_{}", URL_SAFE_NO_PAD.encode(bytes))
}

/// Constant-time equality for the echoed request hash.
fn same_hash(echoed: &str, expected: &[u8; 32]) -> bool {
    let Ok(bytes) = hex::decode(echoed.trim_start_matches("0x")) else {
        return false;
    };
    bytes.len() == 32
        && bytes
            .iter()
            .zip(expected)
            .fold(0_u8, |acc, (a, b)| acc | (a ^ b))
            == 0
}

fn tx_hash_hex(hash: &str) -> String {
    let hex = hash.trim_start_matches("0x").to_ascii_lowercase();
    format!("0x{hex}")
}

impl Engine {
    pub fn new(session: Session, config: Config) -> Self {
        Self {
            wallet: tokio::sync::Mutex::new(AutoLock::new(session)),
            state: Mutex::new(State::default()),
            config,
        }
    }

    fn state(&self) -> std::sync::MutexGuard<'_, State> {
        // A panic while holding it leaves plain data; keep serving.
        self.state
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner)
    }

    /// Run `f` with the unlocked session (fails with `Locked` otherwise).
    pub async fn with_session<T>(
        &self,
        f: impl AsyncFnOnce(&mut Session) -> Result<T>,
    ) -> Result<T> {
        let mut wallet = self.wallet.lock().await;
        f(wallet.session()?).await
    }

    /// Lock now; the pending request expires with it.
    pub async fn lock(&self) -> Result<()> {
        self.expire_pending("wallet locked");
        self.wallet.lock().await.lock()
    }

    /// Host timer: auto-lock when idle (also expires the pending request).
    pub async fn tick(&self) -> Result<bool> {
        let locked = self.wallet.lock().await.tick()?;
        if locked {
            self.expire_pending("wallet locked");
        }
        Ok(locked)
    }

    /// Switch to another unlocked session (zone switch, unlock after lock).
    pub async fn set_session(&self, session: Session) -> Result<()> {
        self.expire_pending("wallet or zone changed");
        self.wallet.lock().await.set(session)
    }

    fn expire_pending(&self, why: &str) {
        let mut state = self.state();
        if let Some(p) = state.pending.take() {
            Self::finish(&mut state, &p.handle, Lifecycle::Expired, Some(why));
        }
    }

    fn finish(state: &mut State, handle: &str, lifecycle: Lifecycle, error: Option<&str>) {
        if let Some(s) = state.statuses.get_mut(handle) {
            s.lifecycle = lifecycle;
            s.phase_started_ms = now_ms();
            s.error = error.map(str::to_owned);
        }
    }

    /// Resolve who the request is for, or refuse the caller.
    fn requester_for(caller: &Caller, relayed: Option<&str>) -> Result<Option<String>> {
        match caller {
            // Our UI relays the shell-attested requester (None: the user themself).
            Caller::WalletUi => Ok(relayed.map(str::to_owned)),
            Caller::LocalOwner => Ok(None),
            Caller::Module(name) => Ok(Some(name.clone())),
            Caller::Host | Caller::Bridge | Caller::Unknown => Err(Denied::err(
                Code::Unauthorized,
                "this caller can't make wallet requests",
            )),
        }
    }

    /// Room for a new request: none pending (an expired one is cleared).
    fn check_free(state: &mut State) -> Result<()> {
        if let Some(p) = &state.pending {
            if Instant::now() < p.deadline {
                return Err(Denied::err(
                    Code::RequestPending,
                    "a request is already open in your wallet",
                ));
            }
            let handle = p.handle.clone();
            state.pending = None;
            Self::finish(
                state,
                &handle,
                Lifecycle::Expired,
                Some("not approved in time"),
            );
        }
        Ok(())
    }

    // -- requests --------------------------------------------------------------

    /// Ask to send a transaction. The wallet UI (or CLI) must then approve it.
    pub async fn request_tx(
        &self,
        caller: &Caller,
        relayed: Option<&str>,
        intent: Intent,
    ) -> Result<Ticket> {
        let requester = Self::requester_for(caller, relayed)?;
        let mut wallet = self.wallet.lock().await;
        let session = wallet.session()?;
        let zone = session.zone().id.clone();
        if let (Caller::Module(name), false) = (
            caller,
            policy::allows(
                session.grants(),
                &zone,
                requester.as_deref().unwrap_or(""),
                intent.from_account(),
                Capability::ProposeTx,
            ),
        ) {
            return Err(Denied::err(
                Code::Unauthorized,
                format!("{name} isn't connected to {}", intent.from_account()),
            ));
        }
        Self::check_free(&mut self.state())?;
        let private = intent.is_private();
        let large = intent.amount() >= self.config.reauth_at;
        let prepared = session.prepare(requester.as_deref(), intent).await?;
        drop(wallet);

        let handle = new_handle();
        let review = prepared.review.clone();
        let mut state = self.state();
        // Checked again: another request may have arrived while we built this one.
        Self::check_free(&mut state)?;
        state.statuses.insert(
            handle.clone(),
            TxStatus {
                handle: handle.clone(),
                chain: review.chain.clone(),
                lifecycle: Lifecycle::AwaitingApproval,
                outcome: Outcome::Unknown,
                outcome_source: OutcomeSource::None,
                tx_hash: None,
                block: None,
                phase_started_ms: now_ms(),
                error: None,
                requester: requester.clone(),
            },
        );
        state.pending = Some(Pending {
            handle: handle.clone(),
            requester,
            hash: *prepared.hash(),
            kind: Kind::Tx(Box::new(prepared)),
            needs_password: private || large,
            deadline: Instant::now() + REQUEST_TTL,
        });
        Ok(Ticket {
            handle,
            request: RequestView::Transaction(review),
            needs_password: private || large,
            expires_in_ms: u64::try_from(REQUEST_TTL.as_millis()).unwrap_or(u64::MAX),
        })
    }

    /// Ask to connect: `capabilities` on `accounts` for the requester.
    pub async fn request_connect(
        &self,
        caller: &Caller,
        relayed: Option<&str>,
        accounts: Vec<String>,
        capabilities: Vec<Capability>,
    ) -> Result<Ticket> {
        let requester = Self::requester_for(caller, relayed)?
            .context("a connect request needs a requesting app")
            .map_err(|e| Denied::err(Code::InvalidParams, e.to_string()))?;
        let chain = self
            .with_session(async |s| {
                let mine: Vec<String> = s.accounts()?.into_iter().map(|a| a.account_id).collect();
                for a in &accounts {
                    if !mine.contains(a) {
                        return Err(Denied::err(
                            Code::InvalidParams,
                            format!("{a} is not an account of this wallet"),
                        ));
                    }
                }
                Ok(s.zone().chain.clone())
            })
            .await?;
        let hash = connect_hash(&chain, &requester, &accounts, &capabilities);
        let handle = new_handle();
        let mut state = self.state();
        Self::check_free(&mut state)?;
        state.pending = Some(Pending {
            handle: handle.clone(),
            requester: Some(requester.clone()),
            kind: Kind::Connect {
                requester: requester.clone(),
                accounts: accounts.clone(),
                capabilities: capabilities.clone(),
            },
            hash,
            needs_password: true,
            deadline: Instant::now() + REQUEST_TTL,
        });
        Ok(Ticket {
            handle,
            request: RequestView::Connect {
                requester,
                chain,
                accounts,
                capabilities,
                request_hash: hex::encode(hash),
            },
            needs_password: true,
            expires_in_ms: u64::try_from(REQUEST_TTL.as_millis()).unwrap_or(u64::MAX),
        })
    }

    /// Decline a pending request: the owner, or the app that asked (cancel).
    pub fn reject(&self, caller: &Caller, handle: &str) -> Result<()> {
        let mut state = self.state();
        let Some(p) = state.pending.as_ref().filter(|p| p.handle == handle) else {
            return Err(Denied::err(Code::UnknownHandle, "no such pending request"));
        };
        let own = matches!(caller, Caller::Module(n) if p.requester.as_deref() == Some(n));
        if !caller.is_owner() && !own {
            return Err(Denied::err(Code::UnknownHandle, "no such pending request"));
        }
        state.pending = None;
        Self::finish(&mut state, handle, Lifecycle::Rejected, Some("declined"));
        Ok(())
    }

    /// Stop a transaction that is being proved: nothing will be signed.
    pub fn cancel(&self, caller: &Caller, handle: &str) -> Result<()> {
        let mut state = self.state();
        let visible = state
            .statuses
            .get(handle)
            .is_some_and(|s| Self::may_read(caller, s));
        if !visible || state.proving.as_deref() != Some(handle) {
            return Err(Denied::err(Code::UnknownHandle, "nothing to cancel"));
        }
        state.cancelled.push(handle.to_owned());
        Ok(())
    }

    fn may_read(caller: &Caller, status: &TxStatus) -> bool {
        match caller {
            c if c.is_owner() => true,
            Caller::Module(name) => status.requester.as_deref() == Some(name.as_str()),
            _ => false,
        }
    }

    /// Only the requester and the owner can read a status; to anyone else an
    /// existing handle looks exactly like an unknown one.
    pub fn status(&self, caller: &Caller, handle: &str) -> Result<TxStatus> {
        let state = self.state();
        state
            .statuses
            .get(handle)
            .filter(|s| Self::may_read(caller, s))
            .cloned()
            .ok_or_else(|| Denied::err(Code::UnknownHandle, "unknown transaction handle"))
    }

    // -- approval ------------------------------------------------------------

    /// Approve the pending request `handle`. `echoed_hash` must be the hash
    /// the UI was given; `password` is required when the ticket said so.
    /// `progress` sees every status change (proving can take minutes).
    pub async fn approve(
        &self,
        caller: &Caller,
        handle: &str,
        echoed_hash: &str,
        password: Option<&str>,
        progress: &mut (dyn FnMut(&TxStatus) + Send),
    ) -> Result<TxStatus> {
        if !caller.is_owner() {
            return Err(Denied::err(
                Code::Unauthorized,
                "only the wallet can approve requests",
            ));
        }
        // Atomic take: whatever happens next, this approval is used once.
        let pending = {
            let mut state = self.state();
            match state.pending.take() {
                Some(p) if p.handle == handle => p,
                other => {
                    state.pending = other;
                    return Err(Denied::err(Code::UnknownHandle, "no such pending request"));
                }
            }
        };
        if Instant::now() >= pending.deadline {
            Self::finish(
                &mut self.state(),
                handle,
                Lifecycle::Expired,
                Some("not approved in time"),
            );
            return Err(Denied::err(Code::Timeout, "the request expired"));
        }
        if !same_hash(echoed_hash, &pending.hash) {
            Self::finish(
                &mut self.state(),
                handle,
                Lifecycle::Rejected,
                Some("approval did not match the request"),
            );
            return Err(Denied::err(
                Code::Unauthorized,
                "the approval does not match the request; it was cancelled",
            ));
        }
        if pending.needs_password {
            let checked = self
                .with_session(async |s| match password {
                    Some(pw) => s.reauth(pw),
                    None => Err(Denied::err(
                        Code::Unauthorized,
                        "enter your password to approve",
                    )),
                })
                .await;
            if let Err(e) = checked {
                // A typo doesn't cost the user the request.
                self.state().pending = Some(pending);
                return Err(e);
            }
        }

        match pending.kind {
            Kind::Connect {
                requester,
                accounts,
                capabilities,
            } => {
                self.with_session(async |s| {
                    let zone = s.zone().id.clone();
                    let mut grants = s.grants().to_vec();
                    for account in &accounts {
                        for cap in &capabilities {
                            let g = Grant {
                                zone: zone.clone(),
                                requester: requester.clone(),
                                account: account.clone(),
                                capability: *cap,
                            };
                            if !grants.contains(&g) {
                                grants.push(g);
                            }
                        }
                    }
                    s.set_grants(grants)
                })
                .await?;
                let chain = self
                    .with_session(async |s| Ok(s.zone().chain.clone()))
                    .await?;
                Ok(TxStatus {
                    handle: handle.to_owned(),
                    chain,
                    lifecycle: Lifecycle::Included,
                    outcome: Outcome::Success,
                    outcome_source: OutcomeSource::None,
                    tx_hash: None,
                    block: None,
                    phase_started_ms: now_ms(),
                    error: None,
                    requester: Some(requester),
                })
            }
            Kind::Tx(prepared) => self.run_tx(handle, *prepared, progress).await,
        }
    }

    fn update(
        &self,
        handle: &str,
        progress: &mut (dyn FnMut(&TxStatus) + Send),
        f: impl FnOnce(&mut TxStatus),
    ) -> TxStatus {
        let mut state = self.state();
        let status = state
            .statuses
            .get_mut(handle)
            .expect("status exists for every request");
        f(status);
        let snapshot = status.clone();
        drop(state);
        progress(&snapshot);
        snapshot
    }

    fn phase(
        &self,
        handle: &str,
        lifecycle: Lifecycle,
        progress: &mut (dyn FnMut(&TxStatus) + Send),
    ) {
        self.update(handle, progress, |s| {
            s.lifecycle = lifecycle;
            s.phase_started_ms = now_ms();
        });
    }

    fn fail(
        &self,
        handle: &str,
        lifecycle: Lifecycle,
        e: anyhow::Error,
        progress: &mut (dyn FnMut(&TxStatus) + Send),
    ) -> anyhow::Error {
        self.update(handle, progress, |s| {
            s.lifecycle = lifecycle;
            s.phase_started_ms = now_ms();
            s.error = Some(format!("{e:#}"));
        });
        e
    }

    async fn run_tx(
        &self,
        handle: &str,
        prepared: Prepared,
        progress: &mut (dyn FnMut(&TxStatus) + Send),
    ) -> Result<TxStatus> {
        let shield = match &prepared.review.intent {
            Intent::Shield { to, amount, .. } => Some((to.clone(), *amount)),
            Intent::Transfer { .. } => None,
        };
        let tx_hash = if prepared.needs_proof() {
            {
                let mut state = self.state();
                if state.proving.is_some() {
                    drop(state);
                    let e =
                        Denied::err(Code::RequestPending, "another transaction is being proved");
                    return Err(self.fail(handle, Lifecycle::Dropped, e, progress));
                }
                state.proving = Some(handle.to_owned());
            }
            let before = match &shield {
                Some((to, _)) => self.with_session(async |s| s.balance(to).await).await.ok(),
                None => None,
            };
            let (job, _review, signer, nonce) = prepared.into_proving()?;
            self.phase(handle, Lifecycle::Proving, progress);
            let proved = tokio::task::spawn_blocking(move || job.run()).await;
            let cancelled = {
                let mut state = self.state();
                state.proving = None;
                let hit = state.cancelled.iter().any(|h| h == handle);
                state.cancelled.retain(|h| h != handle);
                hit
            };
            if cancelled {
                let e = Denied::err(Code::UserRejected, "cancelled before signing");
                return Err(self.fail(handle, Lifecycle::Dropped, e, progress));
            }
            let proved = match proved.context("prover thread").and_then(|r| r) {
                Ok(p) => p,
                Err(e) => {
                    let e = Denied::err(Code::ProofFailed, format!("{e:#}"));
                    return Err(self.fail(handle, Lifecycle::Dropped, e, progress));
                }
            };
            self.phase(handle, Lifecycle::Signing, progress);
            let sent = self
                .with_session(async |s| s.submit_proved(signer, nonce, proved).await)
                .await;
            match sent {
                Ok(h) => (h, before),
                Err(e) => return Err(self.fail(handle, Lifecycle::Dropped, e, progress)),
            }
        } else {
            self.phase(handle, Lifecycle::Signing, progress);
            match self
                .with_session(async |s| s.submit_public(prepared).await)
                .await
            {
                Ok(h) => (h, None),
                Err(e) => return Err(self.fail(handle, Lifecycle::Dropped, e, progress)),
            }
        };
        let (tx_hash, before) = tx_hash;

        self.update(handle, progress, |s| {
            s.lifecycle = Lifecycle::Submitted;
            s.phase_started_ms = now_ms();
            s.tx_hash = Some(tx_hash_hex(&tx_hash));
        });
        let block = self
            .with_session(async |s| s.wait_included(&tx_hash).await)
            .await
            .map_err(|e| Denied::err(Code::SubmissionFailed, format!("{e:#}")));
        let block = match block {
            Ok(b) => b,
            Err(e) => return Err(self.fail(handle, Lifecycle::Submitted, e, progress)),
        };
        // Own-account invariant: a shield must have landed in our private account.
        let outcome = match (shield, before) {
            (Some((to, amount)), Some(before)) => {
                let after = self.with_session(async |s| s.balance(&to).await).await.ok();
                match after {
                    Some(after) if after == before.saturating_add(amount) => {
                        (Outcome::Success, OutcomeSource::OwnAccountInvariant)
                    }
                    Some(_) => (Outcome::Failure, OutcomeSource::OwnAccountInvariant),
                    None => (Outcome::Unknown, OutcomeSource::None),
                }
            }
            _ => (Outcome::Unknown, OutcomeSource::None),
        };
        Ok(self.update(handle, progress, |s| {
            s.lifecycle = Lifecycle::Included;
            s.phase_started_ms = now_ms();
            s.block = Some(block);
            (s.outcome, s.outcome_source) = outcome;
        }))
    }
}

fn connect_hash(
    chain: &str,
    requester: &str,
    accounts: &[String],
    caps: &[Capability],
) -> [u8; 32] {
    use sha2::{Digest as _, Sha256};
    let mut h = Sha256::new();
    h.update(b"logos-kit/connect/v1\0");
    let body = serde_json::json!({
        "chain": chain, "requester": requester, "accounts": accounts, "capabilities": caps,
    });
    h.update(body.to_string().as_bytes());
    h.finalize().into()
}
