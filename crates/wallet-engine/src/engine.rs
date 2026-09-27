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
    faucet::{FaucetBackend, FundOutcome},
    policy::{self, Caller, Capability, Code, Denied, Grant},
    session::AccountKind,
    session::Session,
    tx::{self, Intent, Prepared, Review},
};

/// How long a request waits for the user.
pub const REQUEST_TTL: Duration = Duration::from_secs(5 * 60);
/// After an app's request is declined or expires, it waits this long before
/// it can ask again (so it can't keep the one pending slot busy).
pub const APP_COOLDOWN: Duration = Duration::from_secs(30);
/// Statuses kept for reads; the oldest finished ones go first.
const MAX_STATUSES: usize = 256;

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
    /// Why it stopped (the wallet's own UI; apps get only `errorCode`).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error_code: Option<i64>,
    /// One line for activity rows ("Send 12.5 LEZ to …"); owner views only.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub title: Option<String>,
    /// How a transfer travels (private routes prove for minutes).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub route: Option<tx::Route>,
    /// The wallet account it spends from or signs with.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub from: Option<String>,
    #[serde(skip)]
    requester: Option<String>,
}

impl TxStatus {
    fn new(handle: &str, chain: &str, requester: Option<String>) -> Self {
        Self {
            handle: handle.to_owned(),
            chain: chain.to_owned(),
            lifecycle: Lifecycle::AwaitingApproval,
            outcome: Outcome::Unknown,
            outcome_source: OutcomeSource::None,
            tx_hash: None,
            block: None,
            phase_started_ms: now_ms(),
            error: None,
            error_code: None,
            title: None,
            route: None,
            from: None,
            requester,
        }
    }

    /// The app that asked (None: the owner).
    pub fn requester(&self) -> Option<&str> {
        self.requester.as_deref()
    }

    pub const fn is_final(&self) -> bool {
        !matches!(
            self.lifecycle,
            Lifecycle::AwaitingApproval
                | Lifecycle::Building
                | Lifecycle::Proving
                | Lifecycle::Signing
                | Lifecycle::Submitted
        )
    }
}

/// `request_funds` result.
#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Funds {
    #[serde(flatten)]
    pub outcome: FundOutcome,
    /// Which backend paid (shown in the UI).
    pub faucet: String,
    /// The public account the faucet paid.
    pub funded_account: String,
    /// For a private target: the shield waiting for approval.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub shield: Option<Ticket>,
    /// Funded, but the shield couldn't be queued (why).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub shield_error: Option<String>,
}

/// What `request_*` hands the approving UI.
#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Ticket {
    pub handle: String,
    pub request: RequestView,
    /// The approval must carry the password (private route, large amount,
    /// token authority, connect).
    pub needs_password: bool,
    /// The wallet can't decode what this does: approving must acknowledge that.
    pub needs_acknowledgement: bool,
    pub expires_in_ms: u64,
}

#[derive(Clone, Debug, Serialize)]
#[serde(tag = "type", rename_all = "camelCase")]
pub enum RequestView {
    Transaction(Box<Review>),
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
    needs_ack: bool,
    deadline: Instant,
    /// The wallet/zone generation it was built in, and its zone.
    epoch: u64,
    zone: String,
    /// What the approving UI was shown (re-read after a restart of the view).
    ticket: Ticket,
}

#[derive(Default)]
struct State {
    pending: Option<Pending>,
    statuses: HashMap<String, TxStatus>,
    /// Handle of the transaction being proved (one prover slot).
    proving: Option<String>,
    cancelled: Vec<String>,
    /// Bumped on lock, zone switch and unlock: requests from an older
    /// generation are never approved or stored.
    epoch: u64,
    /// App → when it may ask again.
    cooldown: HashMap<String, Instant>,
}

impl State {
    fn insert_status(&mut self, status: TxStatus) {
        if self.statuses.len() >= MAX_STATUSES {
            let mut done: Vec<(u64, String)> = self
                .statuses
                .values()
                .filter(|s| s.is_final())
                .map(|s| (s.phase_started_ms, s.handle.clone()))
                .collect();
            done.sort();
            for (_, h) in done.iter().take(self.statuses.len() + 1 - MAX_STATUSES) {
                self.statuses.remove(h);
            }
        }
        self.statuses.insert(status.handle.clone(), status);
    }
}

/// Holds the one prover slot; released on every exit path, including the
/// approve future being dropped mid-proof.
struct ProvingSlot<'a> {
    engine: &'a Engine,
    handle: String,
}

impl Drop for ProvingSlot<'_> {
    fn drop(&mut self) {
        let mut state = self.engine.state();
        if state.proving.as_deref() == Some(self.handle.as_str()) {
            state.proving = None;
        }
        state.cancelled.retain(|h| *h != self.handle);
    }
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
    /// Not while a proof runs: the user is waiting on it, and locking would
    /// throw the proof away.
    pub async fn tick(&self) -> Result<bool> {
        if self.state().proving.is_some() {
            return Ok(false);
        }
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
        state.epoch += 1;
        if let Some(p) = state.pending.take() {
            Self::finish(&mut state, &p, Lifecycle::Expired, Some(why));
        }
    }

    /// End a request that never ran; an app's declined or expired request
    /// starts its cooldown.
    fn finish(state: &mut State, p: &Pending, lifecycle: Lifecycle, error: Option<&str>) {
        if let Some(s) = state.statuses.get_mut(&p.handle) {
            s.lifecycle = lifecycle;
            s.phase_started_ms = now_ms();
            s.error = error.map(str::to_owned);
        }
        if let Some(app) = &p.requester {
            state
                .cooldown
                .insert(app.clone(), Instant::now() + APP_COOLDOWN);
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

    /// Room for a new request from `requester` (None: the owner). An expired
    /// request is cleared; the owner's own request replaces an app's; an app
    /// in its cooldown waits.
    fn check_free(state: &mut State, requester: Option<&str>) -> Result<()> {
        if let Some(app) = requester
            && state.cooldown.get(app).is_some_and(|t| Instant::now() < *t)
        {
            return Err(Denied::err(
                Code::RequestPending,
                "your last request was just declined; try again shortly",
            ));
        }
        if let Some(p) = state.pending.take() {
            let (lifecycle, why) = if Instant::now() >= p.deadline {
                (Lifecycle::Expired, "not approved in time")
            } else if requester.is_none() && p.requester.is_some() {
                (Lifecycle::Expired, "replaced by the wallet owner's request")
            } else {
                state.pending = Some(p);
                return Err(Denied::err(
                    Code::RequestPending,
                    "a request is already open in your wallet",
                ));
            };
            Self::finish(state, &p, lifecycle, Some(why));
        }
        Ok(())
    }

    /// Refuse to store a request built under an older wallet generation.
    fn check_epoch(state: &State, epoch: u64) -> Result<()> {
        if state.epoch == epoch {
            Ok(())
        } else {
            Err(Denied::err(
                Code::StaleApproval,
                "the wallet was locked or switched zones while this was prepared",
            ))
        }
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
        let epoch = {
            let mut state = self.state();
            Self::check_free(&mut state, requester.as_deref())?;
            state.epoch
        };
        let prepared = session.prepare(requester.as_deref(), intent).await?;
        // Every account that signs authorizes the program, not only `from`:
        // an app needs a grant on each (a Call can name any of ours).
        if let Caller::Module(name) = caller
            && let Some(ungranted) = prepared.review.summary.signers.iter().find(|a| {
                !policy::allows(
                    session.grants(),
                    &zone,
                    requester.as_deref().unwrap_or(""),
                    a,
                    Capability::ProposeTx,
                )
            })
        {
            return Err(Denied::err(
                Code::Unauthorized,
                format!("{name} isn't connected to {ungranted}, which this would sign with"),
            ));
        }
        drop(wallet);
        let review = &prepared.review;
        let token_out = review
            .summary
            .outflows
            .iter()
            .any(|f| f.asset != crate::decode::Asset::Native);
        let needs_password = review.route.is_some_and(tx::Route::is_private)
            || review.native_outflow() >= self.config.reauth_at
            || token_out
            || review.summary.unknown
            || !review.summary.authorities.is_empty();
        let needs_ack = review.summary.unknown;

        let handle = new_handle();
        let review = prepared.review.clone();
        let ticket = Ticket {
            handle: handle.clone(),
            request: RequestView::Transaction(Box::new(review.clone())),
            needs_password,
            needs_acknowledgement: needs_ack,
            expires_in_ms: u64::try_from(REQUEST_TTL.as_millis()).unwrap_or(u64::MAX),
        };
        let mut state = self.state();
        // Checked again: the wallet or the slot may have changed while we built.
        Self::check_epoch(&state, epoch)?;
        Self::check_free(&mut state, requester.as_deref())?;
        let mut status = TxStatus::new(&handle, &review.chain, requester.clone());
        status.title = Some(review.summary.title.clone());
        status.route = review.route;
        status.from = Some(review.intent.from_account().to_owned());
        state.insert_status(status);
        state.pending = Some(Pending {
            handle,
            requester,
            hash: *prepared.hash(),
            kind: Kind::Tx(Box::new(prepared)),
            needs_password,
            needs_ack,
            deadline: Instant::now() + REQUEST_TTL,
            epoch,
            zone,
            ticket: ticket.clone(),
        });
        Ok(ticket)
    }

    /// `lez_requestFunds`: testnet funds for one of this wallet's accounts.
    /// A private target is funded through a public account of ours (`via`,
    /// else the first), and the shield into it is queued for approval (its
    /// ticket is returned). Takes as long as the faucet does; holds no lock.
    pub async fn request_funds<F: FaucetBackend>(
        &self,
        caller: &Caller,
        relayed: Option<&str>,
        account: &str,
        via: Option<&str>,
        faucet: &F,
        request_key: &str,
    ) -> Result<Funds> {
        let requester = Self::requester_for(caller, relayed)?;
        let (target_private, via) = {
            let mut wallet = self.wallet.lock().await;
            let session = wallet.session()?;
            let zone = session.zone().id.clone();
            if let (Caller::Module(name), false) = (
                caller,
                policy::allows(
                    session.grants(),
                    &zone,
                    requester.as_deref().unwrap_or(""),
                    account,
                    Capability::Accounts,
                ),
            ) {
                return Err(Denied::err(
                    Code::Unauthorized,
                    format!("{name} isn't connected to {account}"),
                ));
            }
            let accounts = session.accounts()?;
            let kind = accounts
                .iter()
                .find(|a| a.account_id == account)
                .map(|a| a.kind)
                .ok_or_else(|| {
                    Denied::err(
                        Code::InvalidParams,
                        format!("{account} is not in this wallet"),
                    )
                })?;
            let private = kind == AccountKind::Private;
            let via = if private {
                let v = match via {
                    Some(v) => accounts
                        .iter()
                        .find(|a| a.account_id == v && a.kind == AccountKind::Public),
                    None => accounts.iter().find(|a| a.kind == AccountKind::Public),
                };
                Some(
                    v.ok_or_else(|| {
                        Denied::err(
                            Code::InvalidParams,
                            "funding a private account needs a public account to shield from",
                        )
                    })?
                    .account_id
                    .clone(),
                )
            } else {
                None
            };
            // An app may only have its own accounts funded or shielded from:
            // `via` is revealed to it and linked to the target on chain.
            if let (Caller::Module(name), Some(v)) = (caller, via.as_deref()) {
                let app = requester.as_deref().unwrap_or("");
                for cap in [Capability::Accounts, Capability::ProposeTx] {
                    if !policy::allows(session.grants(), &zone, app, v, cap) {
                        return Err(Denied::err(
                            Code::Unauthorized,
                            format!("{name} isn't connected to {v} to shield from"),
                        ));
                    }
                }
            }
            (private, via)
        };
        if target_private {
            // Don't take funds for a shield that couldn't be queued.
            Self::check_free(&mut self.state(), requester.as_deref())?;
        }
        let public = via.as_deref().unwrap_or(account);
        let id = crate::decode::account_id(public)?;
        let outcome = faucet.fund(id, request_key).await?;
        let (mut shield, mut shield_error) = (None, None);
        if let (FundOutcome::Funded { amount, .. }, true) = (&outcome, target_private) {
            // The funds arrived either way: report them even if the shield
            // can't be queued now (the user can shield later).
            match self
                .request_tx(
                    caller,
                    relayed,
                    Intent::Transfer {
                        from: public.to_owned(),
                        to: Some(account.to_owned()),
                        amount: *amount,
                        token: None,
                        to_keys: None,
                    },
                )
                .await
            {
                Ok(ticket) => shield = Some(ticket),
                Err(e) => shield_error = Some(format!("{e:#}")),
            }
        }
        Ok(Funds {
            outcome,
            faucet: faucet.name().to_owned(),
            funded_account: public.to_owned(),
            shield,
            shield_error,
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
        let epoch = self.state().epoch;
        let (chain, zone) = self
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
                Ok((s.zone().chain.clone(), s.zone().id.clone()))
            })
            .await?;
        let hash = connect_hash(&chain, &zone, &requester, &accounts, &capabilities);
        let handle = new_handle();
        let ticket = Ticket {
            handle: handle.clone(),
            request: RequestView::Connect {
                requester: requester.clone(),
                chain: chain.clone(),
                accounts: accounts.clone(),
                capabilities: capabilities.clone(),
                request_hash: hex::encode(hash),
            },
            needs_password: true,
            needs_acknowledgement: false,
            expires_in_ms: u64::try_from(REQUEST_TTL.as_millis()).unwrap_or(u64::MAX),
        };
        let mut state = self.state();
        Self::check_epoch(&state, epoch)?;
        Self::check_free(&mut state, Some(&requester))?;
        let mut status = TxStatus::new(&handle, &chain, Some(requester.clone()));
        status.title = Some(format!("Connect {requester}"));
        state.insert_status(status);
        state.pending = Some(Pending {
            handle,
            requester: Some(requester.clone()),
            kind: Kind::Connect {
                requester,
                accounts,
                capabilities,
            },
            hash,
            needs_password: true,
            needs_ack: false,
            deadline: Instant::now() + REQUEST_TTL,
            epoch,
            zone,
            ticket: ticket.clone(),
        });
        Ok(ticket)
    }

    /// The open request as the approving UI saw it, with the time left
    /// (None when nothing is open or it just ran out). Owner only.
    pub fn pending(&self, caller: &Caller) -> Option<Ticket> {
        if !caller.is_owner() {
            return None;
        }
        let state = self.state();
        let p = state.pending.as_ref()?;
        let left = p.deadline.checked_duration_since(Instant::now())?;
        let mut ticket = p.ticket.clone();
        ticket.expires_in_ms = u64::try_from(left.as_millis()).unwrap_or(u64::MAX);
        Some(ticket)
    }

    /// Every status this caller may read, newest first.
    pub fn statuses(&self, caller: &Caller) -> Vec<TxStatus> {
        let state = self.state();
        let mut out: Vec<TxStatus> = state
            .statuses
            .values()
            .filter(|s| Self::may_read(caller, s))
            .cloned()
            .collect();
        out.sort_by_key(|s| std::cmp::Reverse(s.phase_started_ms));
        out
    }

    /// Unlocked, time to auto-lock and zone status, without waiting: None
    /// while something holds the wallet (a long sync), so a status poll never
    /// queues behind it.
    pub fn peek(&self) -> Option<(bool, Option<Duration>, Option<crate::session::ZoneStatus>)> {
        let mut wallet = self.wallet.try_lock().ok()?;
        let remaining = wallet.remaining();
        let unlocked = wallet.is_unlocked();
        let status = if unlocked {
            wallet.session_quiet().ok().and_then(|s| s.status().ok())
        } else {
            None
        };
        Some((unlocked, remaining, status))
    }

    /// Whether a session is open (not locked).
    pub async fn is_unlocked(&self) -> bool {
        self.wallet.lock().await.is_unlocked()
    }

    /// Time left before auto-lock (None: locked).
    pub async fn remaining(&self) -> Option<Duration> {
        self.wallet.lock().await.remaining()
    }

    /// Like [`Engine::with_session`], without counting as use: background
    /// sync and the UI's own reads must not keep the wallet unlocked.
    pub async fn with_session_quiet<T>(
        &self,
        f: impl AsyncFnOnce(&mut Session) -> Result<T>,
    ) -> Result<T> {
        let mut wallet = self.wallet.lock().await;
        f(wallet.session_quiet()?).await
    }

    /// Count now as use (the user acted in the wallet UI).
    pub async fn touch(&self) {
        self.wallet.lock().await.touch();
    }

    /// Drop every grant of `requester` (optionally only on `account`) in the
    /// current zone. Owner, or the app itself (disconnect).
    pub async fn revoke(
        &self,
        caller: &Caller,
        requester: &str,
        account: Option<&str>,
    ) -> Result<usize> {
        let own = matches!(caller, Caller::Module(n) if n == requester);
        if !caller.is_owner() && !own {
            return Err(Denied::err(Code::Unauthorized, "not your grants"));
        }
        self.with_session_quiet(async |s| {
            let zone = s.zone().id.clone();
            let before = s.grants().len();
            let kept: Vec<Grant> = s
                .grants()
                .iter()
                .filter(|g| {
                    !(g.zone == zone
                        && g.requester == requester
                        && account.is_none_or(|a| g.account == a))
                })
                .cloned()
                .collect();
            let removed = before - kept.len();
            if removed > 0 {
                s.set_grants(kept)?;
            }
            Ok(removed)
        })
        .await
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
        if let Some(p) = state.pending.take() {
            Self::finish(&mut state, &p, Lifecycle::Rejected, Some("declined"));
        }
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
        let mut status = state
            .statuses
            .get(handle)
            .filter(|s| Self::may_read(caller, s))
            .cloned()
            .ok_or_else(|| Denied::err(Code::UnknownHandle, "unknown transaction handle"))?;
        if !caller.is_owner() {
            // Internal detail (nonces, RPC errors) stays in the wallet.
            status.error = None;
        }
        Ok(status)
    }

    // -- approval ------------------------------------------------------------

    /// Approve the pending request `handle`. `echoed_hash` must be the hash
    /// the UI was given; `password` is required when the ticket said so, and
    /// `acknowledged_unknown` when it said the wallet can't decode the request.
    /// `progress` sees every status change (proving can take minutes).
    pub async fn approve(
        &self,
        caller: &Caller,
        handle: &str,
        echoed_hash: &str,
        password: Option<&str>,
        acknowledged_unknown: bool,
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
                &pending,
                Lifecycle::Expired,
                Some("not approved in time"),
            );
            return Err(Denied::err(Code::Timeout, "the request expired"));
        }
        if !same_hash(echoed_hash, &pending.hash) {
            Self::finish(
                &mut self.state(),
                &pending,
                Lifecycle::Rejected,
                Some("approval did not match the request"),
            );
            return Err(Denied::err(
                Code::Unauthorized,
                "the approval does not match the request; it was cancelled",
            ));
        }
        if pending.needs_ack && !acknowledged_unknown {
            // Not a rejection: the UI must show the warning and ask again
            // (unless the wallet moved on meanwhile).
            let mut state = self.state();
            if state.pending.is_none() && state.epoch == pending.epoch {
                state.pending = Some(pending);
            } else {
                Self::finish(
                    &mut state,
                    &pending,
                    Lifecycle::Expired,
                    Some("wallet changed"),
                );
            }
            return Err(Denied::err(
                Code::Unauthorized,
                "the wallet can't read what this does; acknowledge that to approve",
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
                // A typo doesn't cost the user the request, unless the wallet
                // moved on meanwhile (lock, zone switch, a newer request).
                let mut state = self.state();
                if state.pending.is_none() && state.epoch == pending.epoch {
                    state.pending = Some(pending);
                } else {
                    Self::finish(
                        &mut state,
                        &pending,
                        Lifecycle::Expired,
                        Some("wallet changed"),
                    );
                }
                return Err(e);
            }
        }
        let (epoch, zone) = (pending.epoch, pending.zone.clone());

        match pending.kind {
            Kind::Connect {
                requester,
                accounts,
                capabilities,
            } => {
                self.with_session(async |s| {
                    self.same_wallet(epoch, &zone, s)?;
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
                Ok(self.update(handle, progress, |s| {
                    s.lifecycle = Lifecycle::Included;
                    s.outcome = Outcome::Success;
                    s.phase_started_ms = now_ms();
                }))
            }
            Kind::Tx(prepared) => self.run_tx(handle, *prepared, epoch, &zone, progress).await,
        }
    }

    /// The session is still the one the request was built for.
    fn same_wallet(&self, epoch: u64, zone: &str, s: &Session) -> Result<()> {
        if self.state().epoch != epoch || s.zone().id != zone {
            return Err(Denied::err(
                Code::StaleApproval,
                "the wallet was locked or switched zones since you approved",
            ));
        }
        Ok(())
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
        let code = policy::code_of(&e) as i64;
        self.update(handle, progress, |s| {
            s.lifecycle = lifecycle;
            s.phase_started_ms = now_ms();
            s.error = Some(format!("{e:#}"));
            s.error_code = Some(code);
        });
        e
    }

    async fn run_tx(
        &self,
        handle: &str,
        prepared: Prepared,
        epoch: u64,
        zone: &str,
        progress: &mut (dyn FnMut(&TxStatus) + Send),
    ) -> Result<TxStatus> {
        // Own-account invariant: which of our private accounts must move, by how much.
        let watch = own_invariant(&prepared.review);
        // Public: our sender's native outflow and the fee cap.
        let public_watch = public_invariant(&prepared.review);
        // A testimonial post proves itself by the record it writes.
        let post =
            crate::testimonial::watch(prepared.review.program.as_ref(), prepared.public_message());
        let tx_hash = if prepared.needs_proof() {
            let (job, pins) = prepared.into_proving()?;
            let slot = {
                let mut state = self.state();
                if state.proving.is_some() {
                    drop(state);
                    let e =
                        Denied::err(Code::RequestPending, "another transaction is being proved");
                    return Err(self.fail(handle, Lifecycle::Dropped, e, progress));
                }
                state.proving = Some(handle.to_owned());
                ProvingSlot {
                    engine: self,
                    handle: handle.to_owned(),
                }
            };
            let before = match &watch {
                Some((account, token, _)) => self
                    .with_session(async |s| s.balance_of(account, token.as_deref()).await)
                    .await
                    .ok(),
                None => None,
            };
            self.phase(handle, Lifecycle::Proving, progress);
            let proved = tokio::task::spawn_blocking(move || job.run()).await;
            let cancelled = self.state().cancelled.iter().any(|h| h == handle);
            drop(slot);
            // The user sat through the proof: that counts as use.
            self.wallet.lock().await.touch();
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
                .with_session(async |s| {
                    self.same_wallet(epoch, zone, s)?;
                    s.submit_proved(&pins, proved).await
                })
                .await;
            match sent {
                Ok(h) => (h, before),
                Err(e) => return Err(self.fail(handle, Lifecycle::Dropped, e, progress)),
            }
        } else {
            self.phase(handle, Lifecycle::Signing, progress);
            match self
                .with_session(async |s| {
                    self.same_wallet(epoch, zone, s)?;
                    // Public native outflow: the sender's balance is the evidence.
                    let before = match &public_watch {
                        Some((from, _, _)) => s.balance_of(from, None).await.ok(),
                        None => None,
                    };
                    Ok((s.submit_public(prepared).await?, before))
                })
                .await
            {
                Ok((h, before)) => (h, before),
                Err(e) => return Err(self.fail(handle, Lifecycle::Dropped, e, progress)),
            }
        };
        let (tx_hash, before) = tx_hash;

        self.update(handle, progress, |s| {
            s.lifecycle = Lifecycle::Submitted;
            s.phase_started_ms = now_ms();
            s.tx_hash = Some(tx_hash_hex(&tx_hash));
        });
        // A poll that gives up leaves the outcome unknown, not failed: the
        // transaction may still land (retrying could send it twice).
        let included = self
            .with_session(async |s| s.wait_included(&tx_hash).await)
            .await
            .map_err(|e| {
                Denied::err(
                    Code::Timeout,
                    format!("sent, not seen in a block yet: {e:#}"),
                )
            });
        let (block, warning) = match included {
            Ok(done) => done,
            Err(e) => return Err(self.fail(handle, Lifecycle::Submitted, e, progress)),
        };
        // Own-account invariant: our private account moved by exactly the amount.
        let outcome = match (watch, before) {
            (Some((account, token, delta)), Some(before)) => {
                let after = self
                    .with_session(async |s| s.balance_of(&account, token.as_deref()).await)
                    .await
                    .ok();
                let expected = if delta >= 0 {
                    before.checked_add(delta.unsigned_abs())
                } else {
                    before.checked_sub(delta.unsigned_abs())
                };
                match after {
                    // The note wasn't recorded locally: the balance proves nothing yet.
                    _ if warning.is_some() => (Outcome::Unknown, OutcomeSource::None),
                    Some(after) if Some(after) == expected => {
                        (Outcome::Success, OutcomeSource::OwnAccountInvariant)
                    }
                    // Included, note recorded, and our account didn't move.
                    Some(after) if after == before => {
                        (Outcome::Failure, OutcomeSource::OwnAccountInvariant)
                    }
                    // Moved by another amount (e.g. another note arrived).
                    _ => (Outcome::Unknown, OutcomeSource::None),
                }
            }
            // Public native outflow: the sender dropped by the amount plus a
            // fee within the approved cap. Anything else (an incoming payment
            // in between, only the fee charged) proves nothing either way.
            (None, Some(before)) if public_watch.is_some() && post.is_none() => {
                let (from, out, max_fee) = public_watch.clone().unwrap_or_default();
                let after = self
                    .with_session(async |s| s.balance_of(&from, None).await)
                    .await
                    .ok();
                match after.and_then(|a| before.checked_sub(a)) {
                    Some(d) if d >= out && d <= out.saturating_add(max_fee) => {
                        (Outcome::Success, OutcomeSource::OwnAccountInvariant)
                    }
                    _ => (Outcome::Unknown, OutcomeSource::None),
                }
            }
            _ => match post {
                Some(post) => match self
                    .with_session(async |s| {
                        let core = s.core().context("not connected")?;
                        crate::testimonial::observe(core, &post).await
                    })
                    .await
                {
                    // The record is keyed by our author account.
                    Ok(Some(true)) => (Outcome::Success, OutcomeSource::OwnAccountInvariant),
                    Ok(Some(false)) => (Outcome::Failure, OutcomeSource::OwnAccountInvariant),
                    _ => (Outcome::Unknown, OutcomeSource::None),
                },
                None => (Outcome::Unknown, OutcomeSource::None),
            },
        };
        Ok(self.update(handle, progress, |s| {
            s.lifecycle = Lifecycle::Included;
            s.phase_started_ms = now_ms();
            s.block = Some(block);
            (s.outcome, s.outcome_source) = outcome;
            s.error = warning;
        }))
    }
}

/// For public transactions: the sending account of ours, its native outflow,
/// and the fee cap it approved.
fn public_invariant(review: &Review) -> Option<(String, u128, u128)> {
    if review.route.is_some_and(tx::Route::is_private) {
        return None;
    }
    let from = review.intent.from_account().to_owned();
    let out: u128 = review
        .summary
        .outflows
        .iter()
        .filter(|f| f.asset == crate::decode::Asset::Native && f.account == from)
        .fold(0u128, |a, f| a.saturating_add(f.amount));
    let max_fee: u128 = review.fee.max_fee.as_deref()?.parse().ok()?;
    (out > 0).then_some((from, out, max_fee))
}

/// For private routes: the private account of ours whose balance must change,
/// the asset, and the signed change (a shield credits, a spend debits).
fn own_invariant(review: &Review) -> Option<(String, Option<String>, i128)> {
    let Intent::Transfer {
        from,
        amount,
        token,
        ..
    } = &review.intent
    else {
        return None;
    };
    let amount = i128::try_from(*amount).ok()?;
    match review.route? {
        tx::Route::Shield => Some((review.recipient.clone()?, token.clone(), amount)),
        tx::Route::Unshield | tx::Route::Private => Some((from.clone(), token.clone(), -amount)),
        tx::Route::Public => None,
    }
}

fn connect_hash(
    chain: &str,
    zone: &str,
    requester: &str,
    accounts: &[String],
    caps: &[Capability],
) -> [u8; 32] {
    use sha2::{Digest as _, Sha256};
    let mut h = Sha256::new();
    h.update(b"logos-kit/connect/v1\0");
    let body = serde_json::json!({
        "chain": chain, "zone": zone, "requester": requester, "accounts": accounts, "capabilities": caps,
    });
    h.update(body.to_string().as_bytes());
    h.finalize().into()
}
