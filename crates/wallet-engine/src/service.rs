//! The wallet as a long-lived service, for the Basecamp module shim.
//!
//! The shim links this crate as a dylib and forwards every call as JSON:
//! `{"method", "params", "caller"}`. `caller` is what the host attested
//! (`current_caller()`), never something the calling app wrote: the shim
//! builds the envelope and the app's JSON only ever lands in `params`.
//!
//! - One tokio runtime for the process. Calls block the shim's dispatch thread
//!   for at most [`CALL_BUDGET`] (below the host's 20 s call timeout); longer
//!   work (proving, faucet waits) runs on the runtime and is read back by
//!   handle, so an approval answers at acceptance.
//! - Background loop while unlocked: auto-lock ticks, sync, and a portfolio
//!   snapshot the UI reads without touching the network.
//! - Events are queued and drained by the shim on its own dispatch thread (the
//!   host's emit callback is not documented as thread-safe). They carry
//!   handles and kinds only, never private data.
//! - `ui_*` methods answer only our wallet UI module (`WalletUi`); the rest are
//!   LWS-0 and follow the grants in `policy.rs`.

use std::{
    collections::{HashMap, VecDeque},
    path::PathBuf,
    sync::{Arc, Mutex, OnceLock},
    time::{Duration, Instant},
};

use anyhow::{Context as _, Result, ensure};
use base64::{
    Engine as _,
    engine::general_purpose::{STANDARD, URL_SAFE_NO_PAD},
};
use lee::ProgramShardSelector;
use sequencer_service_rpc::{RpcClient as _, SequencerClient, SequencerClientBuilder};
use serde::{Deserialize, Serialize, de::DeserializeOwned};
use serde_json::{Value, json};
use sha2::{Digest as _, Sha256};
use zeroize::Zeroizing;

use crate::{
    engine::{Config, Engine, Lifecycle, Ticket, TxStatus},
    faucet::{HttpFaucet, KeyFaucet},
    message::{self, SignInRequest},
    policy::{self, Caller, Capability, Code, Denied},
    session::{AccountKind, Birthday, DataDir, NetStatus, Session, Zone},
    tx::{CallAccount, Intent, RecipientKeys, Route},
    vault::KdfCost,
};

/// The wallet UI module: the only caller that can approve.
pub const WALLET_UI_MODULE: &str = "logos_kit_wallet_ui";
/// Longest a call may hold the shim's dispatch thread.
const CALL_BUDGET: Duration = Duration::from_secs(15);
/// How long `ui_approve` waits to learn the approval was accepted.
const ACCEPT_WAIT: Duration = Duration::from_secs(10);
const SYNC_EVERY: Duration = Duration::from_secs(12);
const TICK_EVERY: Duration = Duration::from_secs(3);
const MAX_EVENTS: usize = 256;
/// Wrong passwords before the unlock screen waits.
const UNLOCK_TRIES: u32 = 5;
const UNLOCK_COOLDOWN: Duration = Duration::from_secs(30);
/// LEZ debug-genesis key (public, in LEZ's own Justfile): the local zone's faucet.
const LOCAL_GENESIS_KEY: &str = "7f273098f25b71e6c005a9519f2678da8d1c7f01f6a27778e2d9948abdf901fb";
/// Proving time on a desktop CPU, from the S3 benchmarks (seconds).
const ETA_SHIELD_S: u64 = 330;
const ETA_PRIVATE_S: u64 = 420;

static SERVICE: OnceLock<Service> = OnceLock::new();

/// Settings the UI owns (not secret): which zone to open, the look, faucets.
#[derive(Clone, Debug, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
struct Prefs {
    zone: Option<String>,
    /// Zones the user added (the built-in ones are always listed).
    zones: Vec<Zone>,
    theme: Option<String>,
    /// Zone id → drip service URL.
    faucets: HashMap<String, String>,
}

#[derive(Clone, Debug, Default, Serialize)]
#[serde(rename_all = "camelCase")]
struct Snapshot {
    accounts: Vec<Value>,
    updated_ms: u64,
    tip: Option<u64>,
    error: Option<String>,
}

struct Throttle {
    fails: u32,
    until: Option<Instant>,
}

pub struct Service {
    rt: tokio::runtime::Runtime,
    data: DataDir,
    prefs: Mutex<Prefs>,
    engine: Mutex<Option<Arc<Engine>>>,
    events: Mutex<VecDeque<Value>>,
    /// `zone|requester|account|id` → handle (LWS-0 proposal ids).
    ids: Mutex<HashMap<String, String>>,
    /// Faucet job id → its state.
    jobs: Mutex<HashMap<String, Value>>,
    snapshot: Mutex<Snapshot>,
    /// The last ui_state wallet fields, served while a sync holds the wallet.
    last_state: Mutex<Option<(bool, Option<u64>, Option<Value>)>>,
    throttle: Mutex<Throttle>,
    /// Bumped on every unlock; an older background loop stops.
    generation: Mutex<u64>,
    refresh: tokio::sync::Notify,
}

fn lock<T>(m: &Mutex<T>) -> std::sync::MutexGuard<'_, T> {
    m.lock().unwrap_or_else(std::sync::PoisonError::into_inner)
}

fn now_ms() -> u64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map_or(0, |d| u64::try_from(d.as_millis()).unwrap_or(u64::MAX))
}

fn invalid(msg: impl Into<String>) -> anyhow::Error {
    Denied::err(Code::InvalidParams, msg)
}

fn params<T: DeserializeOwned>(p: &Value) -> Result<T> {
    serde_json::from_value(p.clone()).map_err(|e| invalid(format!("invalid params: {e}")))
}

/// Who called, from the host-attested identity the shim passes.
fn caller_of(v: &Value) -> Caller {
    match (
        v.get("kind").and_then(Value::as_str),
        v.get("name").and_then(Value::as_str),
    ) {
        (Some("module"), Some(WALLET_UI_MODULE)) => Caller::WalletUi,
        (Some("module"), Some(name)) if valid_module_name(name) => Caller::Module(name.to_owned()),
        // In-process only (tests, the CLI): the shim never sends it.
        (Some("local_owner"), _) => Caller::LocalOwner,
        (Some("host"), _) => Caller::Host,
        _ => Caller::Unknown,
    }
}

fn valid_module_name(n: &str) -> bool {
    (1..=64).contains(&n.len())
        && n.bytes()
            .all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || b == b'_' || b == b'-')
}

/// Error JSON. Apps get the user-safe copy for internal errors (paths,
/// RPC detail stay in the wallet); the wallet UI gets the full chain.
fn error_json(e: &anyhow::Error, caller: &Caller) -> Value {
    let code = policy::code_of(e);
    let message = if caller.is_owner() || code != Code::Internal {
        format!("{e:#}")
    } else {
        "the wallet hit an internal error".to_owned()
    };
    let mut err = json!({ "code": code as i64, "message": message });
    if let Some(d) = e.downcast_ref::<WithData>() {
        err["data"] = d.data.clone();
        err["code"] = json!(d.code);
    }
    json!({ "ok": false, "error": err })
}

/// An error that carries LWS-0 `data` (e.g. the handle of a duplicate id).
#[derive(Debug)]
struct WithData {
    code: i64,
    message: String,
    data: Value,
}

impl std::fmt::Display for WithData {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(&self.message)
    }
}

impl std::error::Error for WithData {}

// -- entry points (C ABI) -----------------------------------------------------

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct InitConfig {
    data_dir: PathBuf,
}

/// Start the service once (the module's data directory). Later calls are no-ops.
pub fn init(config: &str) -> Value {
    let cfg: InitConfig = match serde_json::from_str(config) {
        Ok(c) => c,
        Err(e) => return crate::api::err(-32602, &format!("init: {e}")),
    };
    if SERVICE.get().is_some() {
        return crate::api::ok(json!({ "started": false }));
    }
    match Service::new(cfg.data_dir) {
        Ok(s) => {
            let _ = SERVICE.set(s);
            crate::api::ok(json!({ "started": true }))
        }
        Err(e) => crate::api::err(-32603, &format!("{e:#}")),
    }
}

/// One call: `{"method", "params", "caller"}`.
pub fn call(request: &str) -> Value {
    let Ok(req) = serde_json::from_str::<Value>(request) else {
        return crate::api::err(-32700, "request is not JSON");
    };
    let Some(method) = req.get("method").and_then(Value::as_str) else {
        return crate::api::err(-32600, "method is required");
    };
    let caller = caller_of(req.get("caller").unwrap_or(&Value::Null));
    let Some(svc) = SERVICE.get() else {
        return crate::api::err(6109, "the wallet service isn't started");
    };
    let p = req.get("params").cloned().unwrap_or_else(|| json!({}));
    let p = if p.is_null() { json!({}) } else { p };
    match svc.dispatch(method, &p, &caller) {
        Ok(v) => crate::api::ok(v),
        Err(e) => error_json(&e, &caller),
    }
}

/// Queued events, oldest first (the shim emits them).
pub fn drain_events() -> Value {
    SERVICE.get().map_or_else(
        || json!([]),
        |s| Value::Array(lock(&s.events).drain(..).collect()),
    )
}

impl Service {
    pub fn new(root: PathBuf) -> Result<Self> {
        let rt = tokio::runtime::Builder::new_multi_thread()
            .worker_threads(2)
            .thread_name("logos-kit-engine")
            .enable_all()
            .build()
            .context("tokio runtime")?;
        let data = DataDir::new(root);
        let prefs = std::fs::read(data.root().join("ui-prefs.json"))
            .ok()
            .and_then(|b| serde_json::from_slice(&b).ok())
            .unwrap_or_default();
        Ok(Self {
            rt,
            data,
            prefs: Mutex::new(prefs),
            engine: Mutex::new(None),
            events: Mutex::new(VecDeque::new()),
            ids: Mutex::new(HashMap::new()),
            jobs: Mutex::new(HashMap::new()),
            snapshot: Mutex::new(Snapshot::default()),
            last_state: Mutex::new(None),
            throttle: Mutex::new(Throttle {
                fails: 0,
                until: None,
            }),
            generation: Mutex::new(0),
            refresh: tokio::sync::Notify::new(),
        })
    }

    fn emit(&self, event: &str, body: Value) {
        let mut q = lock(&self.events);
        if q.len() >= MAX_EVENTS {
            q.pop_front();
        }
        let mut e = json!({ "event": event });
        if let (Some(obj), Value::Object(extra)) = (e.as_object_mut(), body) {
            obj.extend(extra);
        }
        q.push_back(e);
    }

    fn save_prefs(&self, prefs: &Prefs) -> Result<()> {
        crate::vault::private_dir(self.data.root())?;
        crate::vault::atomic_write(
            self.data.root(),
            "ui-prefs.json",
            &serde_json::to_vec_pretty(prefs)?,
        )
    }

    fn zones(&self) -> Vec<Zone> {
        let mut out = vec![Zone::testnet(), Zone::local()];
        for z in &lock(&self.prefs).zones {
            if !out.iter().any(|o| o.id == z.id) {
                out.push(z.clone());
            }
        }
        out
    }

    fn current_zone(&self) -> Zone {
        let want = lock(&self.prefs).zone.clone();
        let zones = self.zones();
        want.and_then(|id| zones.iter().find(|z| z.id == id).cloned())
            .unwrap_or_else(Zone::testnet)
    }

    fn engine(&self) -> Result<Arc<Engine>> {
        lock(&self.engine)
            .clone()
            .ok_or_else(|| Denied::err(Code::Unauthorized, "the wallet is locked"))
    }

    /// Run a future on the runtime, holding the caller for at most the budget.
    fn block<T>(&self, fut: impl Future<Output = Result<T>>) -> Result<T> {
        self.rt.block_on(async {
            tokio::time::timeout(CALL_BUDGET, fut)
                .await
                .map_err(|_| Denied::err(Code::Timeout, "the wallet is busy; try again"))?
        })
    }

    fn client(&self) -> Result<SequencerClient> {
        SequencerClientBuilder::default()
            .build(self.current_zone().sequencer)
            .context("sequencer url")
    }

    // -- dispatch ---------------------------------------------------------------

    fn dispatch(&'static self, method: &str, p: &Value, caller: &Caller) -> Result<Value> {
        if let Some(ui) = method.strip_prefix("ui_") {
            if !caller.is_owner() {
                // Same answer as an unknown method: apps learn nothing.
                return Err(Denied::err(Code::Unauthorized, "unknown method"));
            }
            return self.ui(ui, p, caller);
        }
        match method {
            "lez_getCapabilities" => Ok(capabilities()),
            "lez_readAccount" => self.read_account(p),
            "lez_getSession" => self.get_session(caller),
            "lez_getAccounts" => {
                let app = app_of(caller)?;
                self.granted_accounts(&app)
            }
            "lez_getBalance" => self.get_balance(p, caller),
            "lez_getTransactionStatus" => {
                let h: HandleP = params(p)?;
                let s = self.engine()?.status(caller, &h.handle)?;
                Ok(protocol_status(&s, caller))
            }
            "lez_signAndSendTransaction" => {
                // A module proposing directly: the user approves in the wallet.
                let app = app_of(caller)?;
                let ticket = self.propose(caller, None, &app, p)?;
                self.emit("request_opened", json!({ "handle": ticket.handle }));
                Ok(json!({ "handle": ticket.handle }))
            }
            "lez_disconnect" => {
                let app = app_of(caller)?;
                let engine = self.engine()?;
                self.block(async { engine.revoke(caller, &app, None).await })?;
                Ok(Value::Null)
            }
            "lez_connect" => {
                // Only a silent restore works without the wallet's UI.
                let app = app_of(caller)?;
                if p.get("silent").and_then(Value::as_bool) == Some(true) {
                    let s = self.session_for(&app)?;
                    if !s.is_null() {
                        return Ok(s);
                    }
                }
                Err(Denied::err(
                    Code::Unauthorized,
                    "connect through the lez.wallet.connect intent",
                ))
            }
            "lez_signMessage" | "lez_signIn" | "lez_requestFunds" | "lez_switchChain" => {
                Err(WithData {
                    code: 4200,
                    message: format!("{method} needs the user: use its Basecamp intent"),
                    data: Value::Null,
                }
                .into())
            }
            _ => Err(Denied::err(Code::Unauthorized, "unknown method")),
        }
    }

    fn ui(&'static self, method: &str, p: &Value, caller: &Caller) -> Result<Value> {
        match method {
            "state" => self.state(caller),
            "create" => self.create(p),
            "restore" => self.restore(p),
            "unlock" => self.unlock(p),
            "lock" => {
                if let Ok(engine) = self.engine() {
                    self.block(async { engine.lock().await })?;
                }
                *lock(&self.snapshot) = Snapshot::default();
                self.emit("wallet_changed", json!({ "locked": true }));
                Ok(Value::Null)
            }
            "snapshot" => {
                let snap = lock(&self.snapshot).clone();
                Ok(serde_json::to_value(snap)?)
            }
            "refresh" => {
                self.refresh.notify_one();
                Ok(Value::Null)
            }
            "newAccount" => {
                #[derive(Deserialize)]
                struct P {
                    kind: AccountKind,
                    #[serde(default)]
                    label: Option<String>,
                }
                let a: P = params(p)?;
                let engine = self.engine()?;
                let info = self.block(async {
                    engine
                        .with_session(async |s| {
                            let info = s.new_account(a.kind)?;
                            if let Some(l) = a.label.as_deref().filter(|l| !l.is_empty()) {
                                s.set_label(&info.account_id, Some(l))?;
                            }
                            Ok(info)
                        })
                        .await
                })?;
                self.refresh.notify_one();
                Ok(serde_json::to_value(info)?)
            }
            "setLabel" => {
                #[derive(Deserialize)]
                struct P {
                    account: String,
                    label: Option<String>,
                }
                let a: P = params(p)?;
                let engine = self.engine()?;
                self.block(async {
                    engine
                        .with_session(async |s| {
                            s.set_label(&a.account, a.label.as_deref().filter(|l| !l.is_empty()))
                        })
                        .await
                })?;
                self.refresh.notify_one();
                Ok(Value::Null)
            }
            "receive" => {
                let a: AccountP = params(p)?;
                let engine = self.engine()?;
                self.block(async {
                    engine
                        .with_session_quiet(async |s| {
                            let info = s
                                .accounts()?
                                .into_iter()
                                .find(|x| x.account_id == a.account)
                                .context("no such account in this wallet")?;
                            Ok(match info.kind {
                                AccountKind::Public => json!({
                                    "kind": "public", "account": info.account_id,
                                }),
                                AccountKind::Private => {
                                    let (npk, vpk) = s.receive_keys(&info.account_id)?;
                                    receive_code(&npk, &vpk)
                                }
                            })
                        })
                        .await
                })
            }
            "prepareSend" => {
                let mut p = p.clone();
                if let Some(code) = p.get("toCode").and_then(Value::as_str).map(str::to_owned) {
                    let keys = parse_receive_code(&code).map_err(|e| invalid(format!("{e:#}")))?;
                    p["toKeys"] = serde_json::to_value(keys)?;
                    if let Some(o) = p.as_object_mut() {
                        o.remove("toCode");
                    }
                }
                let intent: Intent = params(&p)?;
                let engine = self.engine()?;
                let ticket = self.block(async { engine.request_tx(caller, None, intent).await })?;
                Ok(serde_json::to_value(ticket)?)
            }
            "requestTx" => {
                #[derive(Deserialize)]
                struct P {
                    requester: String,
                    proposal: Value,
                }
                let a: P = params(p)?;
                check_requester(&a.requester)?;
                let ticket = self.propose(caller, Some(&a.requester), &a.requester, &a.proposal)?;
                Ok(serde_json::to_value(ticket)?)
            }
            "requestConnect" => {
                #[derive(Deserialize)]
                struct P {
                    requester: String,
                    accounts: Vec<String>,
                    capabilities: Vec<Capability>,
                }
                let a: P = params(p)?;
                check_requester(&a.requester)?;
                ensure!(!a.accounts.is_empty(), invalid("pick at least one account"));
                let engine = self.engine()?;
                let ticket = self.block(async {
                    engine
                        .request_connect(caller, Some(&a.requester), a.accounts, a.capabilities)
                        .await
                })?;
                Ok(serde_json::to_value(ticket)?)
            }
            "sessionFor" => {
                let a: RequesterP = params(p)?;
                check_requester(&a.requester)?;
                self.session_for(&a.requester)
            }
            "pending" => {
                let engine = self.engine()?;
                Ok(serde_json::to_value(engine.pending(caller))?)
            }
            "approve" => self.approve(p, caller),
            "reject" => {
                let h: HandleP = params(p)?;
                self.engine()?.reject(caller, &h.handle)?;
                self.emit("request_updated", json!({ "handle": h.handle }));
                Ok(Value::Null)
            }
            "cancel" => {
                let h: HandleP = params(p)?;
                self.engine()?.cancel(caller, &h.handle)?;
                Ok(Value::Null)
            }
            "status" => {
                let h: HandleP = params(p)?;
                let s = self.engine()?.status(caller, &h.handle)?;
                Ok(owner_status(&s))
            }
            "activity" => {
                let engine = self.engine()?;
                Ok(Value::Array(
                    engine.statuses(caller).iter().map(owner_status).collect(),
                ))
            }
            "signMessage" => self.sign_message(p),
            "signIn" => self.sign_in(p),
            "requestFunds" => self.request_funds(p, caller),
            "fundStatus" => {
                #[derive(Deserialize)]
                struct P {
                    job: String,
                }
                let a: P = params(p)?;
                lock(&self.jobs)
                    .get(&a.job)
                    .cloned()
                    .ok_or_else(|| Denied::err(Code::UnknownHandle, "unknown faucet request"))
            }
            "grants" => {
                let engine = self.engine()?;
                self.block(async {
                    engine
                        .with_session_quiet(async |s| {
                            let zone = s.zone().id.clone();
                            Ok(serde_json::to_value(
                                s.grants()
                                    .iter()
                                    .filter(|g| g.zone == zone)
                                    .collect::<Vec<_>>(),
                            )?)
                        })
                        .await
                })
            }
            "revoke" => {
                #[derive(Deserialize)]
                struct P {
                    requester: String,
                    #[serde(default)]
                    account: Option<String>,
                }
                let a: P = params(p)?;
                let engine = self.engine()?;
                let n = self.block(async {
                    engine
                        .revoke(caller, &a.requester, a.account.as_deref())
                        .await
                })?;
                Ok(json!({ "removed": n }))
            }
            "setAutoLock" => {
                #[derive(Deserialize)]
                struct P {
                    secs: u32,
                }
                let a: P = params(p)?;
                let engine = self.engine()?;
                self.block(async { engine.with_session(async |s| s.set_auto_lock(a.secs)).await })?;
                Ok(Value::Null)
            }
            "revealPhrase" => {
                let a: PasswordP = params(p)?;
                let engine = self.engine()?;
                let phrase = self.block(async {
                    engine
                        .with_session(async |s| s.reveal_phrase(&a.password))
                        .await
                })?;
                Ok(json!({ "words": phrase.split_whitespace().collect::<Vec<_>>() }))
            }
            "changePassword" => {
                #[derive(Deserialize)]
                struct P {
                    current: String,
                    new: String,
                }
                let a: P = params(p)?;
                check_password(&a.new)?;
                let engine = self.engine()?;
                self.block(async {
                    engine
                        .with_session(async |s| s.change_password(&a.current, &a.new))
                        .await
                })?;
                Ok(Value::Null)
            }
            "setPrefs" => {
                #[derive(Deserialize)]
                #[serde(rename_all = "camelCase")]
                struct P {
                    #[serde(default)]
                    theme: Option<String>,
                    #[serde(default)]
                    faucet: Option<(String, Option<String>)>,
                    /// The zone to open (while locked; unlocked, use switchZone).
                    #[serde(default)]
                    zone: Option<String>,
                }
                let a: P = params(p)?;
                let mut prefs = lock(&self.prefs).clone();
                if let Some(z) = a.zone {
                    ensure!(
                        self.zones().iter().any(|o| o.id == z),
                        invalid("unknown zone")
                    );
                    let open = match lock(&self.engine).clone() {
                        Some(e) => self.block(async { Ok(e.is_unlocked().await) })?,
                        None => false,
                    };
                    ensure!(
                        !open,
                        invalid("switch zones from Settings (needs your password)")
                    );
                    prefs.zone = Some(z);
                }
                if let Some(t) = a.theme {
                    ensure!(
                        t == "dark" || t == "light",
                        invalid("theme is dark or light")
                    );
                    prefs.theme = Some(t);
                }
                if let Some((zone, url)) = a.faucet {
                    match url.filter(|u| !u.is_empty()) {
                        Some(u) => {
                            HttpFaucet::new("check", &u)?;
                            prefs.faucets.insert(zone, u);
                        }
                        None => {
                            prefs.faucets.remove(&zone);
                        }
                    }
                }
                self.save_prefs(&prefs)?;
                *lock(&self.prefs) = prefs;
                Ok(Value::Null)
            }
            "addZone" => {
                let z: Zone = params(p)?;
                let mut prefs = lock(&self.prefs).clone();
                ensure!(
                    !self.zones().iter().any(|o| o.id == z.id),
                    invalid("a zone with that id exists")
                );
                ensure!(
                    z.sequencer.starts_with("https://")
                        || z.sequencer.starts_with("http://127.0.0.1")
                        || z.sequencer.starts_with("http://localhost"),
                    invalid("the sequencer must be https (or http on this machine)")
                );
                prefs.zones.push(z);
                self.save_prefs(&prefs)?;
                *lock(&self.prefs) = prefs;
                Ok(Value::Null)
            }
            "switchZone" => {
                #[derive(Deserialize)]
                struct P {
                    zone: String,
                    password: String,
                }
                let a: P = params(p)?;
                let zone = self
                    .zones()
                    .into_iter()
                    .find(|z| z.id == a.zone)
                    .ok_or_else(|| invalid("unknown zone"))?;
                // The new session needs the directory lock the old one holds.
                if let Ok(engine) = self.engine() {
                    self.block(async { engine.lock().await })?;
                }
                let mut prefs = lock(&self.prefs).clone();
                prefs.zone = Some(zone.id.clone());
                self.save_prefs(&prefs)?;
                *lock(&self.prefs) = prefs;
                self.unlock(&json!({ "password": a.password }))
            }
            "testZone" => {
                let client = self.client()?;
                let tip = self.block(async {
                    client
                        .get_last_block_id()
                        .await
                        .map_err(|e| Denied::err(Code::ChainDisconnected, format!("{e}")))
                })?;
                Ok(json!({ "tip": tip }))
            }
            "openUrl" => {
                #[derive(Deserialize)]
                struct P {
                    url: String,
                }
                let a: P = params(p)?;
                open_url(&a.url)?;
                Ok(Value::Null)
            }
            "touch" => {
                if let Ok(engine) = self.engine() {
                    self.block(async {
                        engine.touch().await;
                        Ok(())
                    })?;
                }
                Ok(Value::Null)
            }
            _ => Err(Denied::err(Code::Unauthorized, "unknown method")),
        }
    }

    // -- wallet lifecycle -------------------------------------------------------

    fn state(&self, caller: &Caller) -> Result<Value> {
        let zone = self.current_zone();
        let prefs = lock(&self.prefs).clone();
        let engine = lock(&self.engine).clone();
        // Never queue behind a sync: reuse the last answer while it runs.
        let (unlocked, remaining, status, busy) = match &engine {
            Some(e) => match e.peek() {
                Some((u, r, s)) => {
                    let v = (u, r.map(|d| d.as_secs()), s.and_then(|s| serde_json::to_value(s).ok()));
                    *lock(&self.last_state) = Some(v.clone());
                    (v.0, v.1, v.2, false)
                }
                None => match lock(&self.last_state).clone() {
                    Some((u, r, s)) => (u, r, s, true),
                    None => (true, None, None, true),
                },
            },
            None => (false, None, None, false),
        };
        let pending = engine.as_ref().and_then(|e| e.pending(caller));
        let throttle = lock(&self.throttle)
            .until
            .and_then(|t| t.checked_duration_since(Instant::now()))
            .map(|d| d.as_secs() + 1);
        let proving = engine.as_ref().and_then(|e| {
            e.statuses(caller)
                .into_iter()
                .find(|s| !s.is_final() && s.lifecycle != Lifecycle::AwaitingApproval)
                .map(|s| owner_status(&s))
        });
        Ok(json!({
            "initialized": self.data.is_initialized(),
            "unlocked": unlocked,
            "autoLockRemaining": remaining,
            "zone": zone,
            "zones": self.zones(),
            "theme": prefs.theme.clone().unwrap_or_else(|| "dark".into()),
            "faucet": faucet_label(&zone, &prefs),
            "status": status,
            "busy": busy,
            "pending": pending,
            "active": proving,
            "unlockWaitSecs": throttle,
        }))
    }

    fn create(&'static self, p: &Value) -> Result<Value> {
        let a: PasswordP = params(p)?;
        check_password(&a.password)?;
        let zone = self.current_zone();
        let (mut session, phrase) =
            Session::create(self.data.clone(), &a.password, zone, KdfCost::DEFAULT)?;
        // The first-run screen shows one public and one private account.
        if session.accounts()?.is_empty() {
            session.new_account(AccountKind::Public)?;
        }
        if !session
            .accounts()?
            .iter()
            .any(|x| x.kind == AccountKind::Private)
        {
            session.new_account(AccountKind::Private)?;
        }
        name_defaults(&mut session)?;
        let accounts = session.accounts()?;
        self.open(session)?;
        Ok(json!({
            "words": phrase.split_whitespace().collect::<Vec<_>>(),
            "accounts": accounts,
        }))
    }

    fn restore(&'static self, p: &Value) -> Result<Value> {
        #[derive(Deserialize)]
        #[serde(rename_all = "camelCase")]
        struct P {
            password: String,
            phrase: String,
            /// Unix ms; absent scans the whole chain.
            #[serde(default)]
            birthday_ms: Option<u64>,
        }
        let a: P = params(p)?;
        check_password(&a.password)?;
        let phrase = Zeroizing::new(a.phrase.split_whitespace().collect::<Vec<_>>().join(" "));
        let birthday = a.birthday_ms.map_or(Birthday::Genesis, Birthday::At);
        let session = Session::restore(
            self.data.clone(),
            &a.password,
            &phrase,
            birthday,
            self.current_zone(),
            KdfCost::DEFAULT,
        )?;
        self.open(session)?;
        Ok(Value::Null)
    }

    fn unlock(&'static self, p: &Value) -> Result<Value> {
        let a: PasswordP = params(p)?;
        {
            let t = lock(&self.throttle);
            if let Some(left) = t
                .until
                .and_then(|u| u.checked_duration_since(Instant::now()))
            {
                return Err(WithData {
                    code: Code::RequestPending as i64,
                    message: format!("too many tries; wait {}s", left.as_secs() + 1),
                    data: json!({ "retryInSecs": left.as_secs() + 1 }),
                }
                .into());
            }
        }
        if let Ok(engine) = self.engine()
            && self.block(async { Ok(engine.is_unlocked().await) })?
        {
            return Ok(Value::Null);
        }
        match Session::unlock(self.data.clone(), &a.password, self.current_zone()) {
            Ok(session) => {
                *lock(&self.throttle) = Throttle {
                    fails: 0,
                    until: None,
                };
                self.open(session)?;
                Ok(Value::Null)
            }
            Err(e) => {
                let wrong = format!("{e:#}").contains("password");
                if wrong {
                    let mut t = lock(&self.throttle);
                    t.fails += 1;
                    if t.fails >= UNLOCK_TRIES {
                        t.fails = 0;
                        t.until = Some(Instant::now() + UNLOCK_COOLDOWN);
                    }
                    return Err(Denied::err(Code::Unauthorized, "wrong password"));
                }
                Err(e)
            }
        }
    }

    /// Put an unlocked session to work and start its background loop.
    fn open(&'static self, session: Session) -> Result<()> {
        let existing = lock(&self.engine).clone();
        let engine = match existing {
            Some(e) => {
                self.block(async { e.set_session(session).await })?;
                e
            }
            None => {
                let e = Arc::new(Engine::new(session, Config::default()));
                *lock(&self.engine) = Some(Arc::clone(&e));
                e
            }
        };
        let generation = {
            let mut g = lock(&self.generation);
            *g += 1;
            *g
        };
        *lock(&self.snapshot) = Snapshot::default();
        self.emit("wallet_changed", json!({ "locked": false }));
        self.detached("logos-kit-sync", move || {
            background(self, engine, generation)
        });
        Ok(())
    }
}

// -- requests, approval, signatures -------------------------------------------

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct Proposal {
    chain: String,
    account: String,
    #[serde(default)]
    id: Option<String>,
    instructions: Vec<Instruction>,
    #[serde(default)]
    atomic_required: Option<bool>,
}

#[derive(Deserialize)]
struct Instruction {
    program: String,
    accounts: Vec<InstructionAccount>,
    data: String,
}

#[derive(Deserialize)]
struct InstructionAccount {
    account: String,
    #[serde(default)]
    signer: bool,
}

#[derive(Deserialize)]
struct HandleP {
    handle: String,
}

#[derive(Deserialize)]
struct AccountP {
    account: String,
}

#[derive(Deserialize)]
struct RequesterP {
    requester: String,
}

#[derive(Deserialize)]
struct PasswordP {
    password: String,
}

fn coded(code: i64, message: impl Into<String>, data: Value) -> anyhow::Error {
    WithData {
        code,
        message: message.into(),
        data,
    }
    .into()
}

impl Service {
    /// An app's `TransactionProposal` → a pending request (one call, public).
    fn propose(
        &'static self,
        caller: &Caller,
        relayed: Option<&str>,
        app: &str,
        proposal: &Value,
    ) -> Result<Ticket> {
        let prop: Proposal = params(proposal)?;
        let zone = self.current_zone();
        if prop.chain != zone.chain {
            return Err(coded(
                4902,
                format!("the wallet is on {}, not {}", zone.chain, prop.chain),
                json!({ "chain": zone.chain }),
            ));
        }
        if prop.instructions.len() > 1 {
            let code = if prop.atomic_required == Some(true) {
                5760
            } else {
                5740
            };
            return Err(coded(
                code,
                "one instruction per transaction",
                json!({ "max": 1 }),
            ));
        }
        let Some(ix) = prop.instructions.into_iter().next() else {
            return Err(invalid("a proposal needs an instruction"));
        };
        if prop.account.starts_with("pvt_")
            || ix.accounts.iter().any(|a| a.account.starts_with("pvt_"))
        {
            return Err(coded(
                6100,
                "apps propose public transactions; private transfers start in the wallet",
                Value::Null,
            ));
        }
        let key = match &prop.id {
            Some(id) => {
                ensure!(
                    (1..=64).contains(&id.len()),
                    invalid("id must be 1–64 characters")
                );
                let key = format!("{}|{app}|{}|{id}", zone.id, prop.account);
                if let Some(handle) = lock(&self.ids).get(&key) {
                    return Err(coded(
                        5720,
                        "this proposal id was already used",
                        json!({ "handle": handle }),
                    ));
                }
                Some(key)
            }
            None => None,
        };
        let intent = Intent::Call {
            from: prop.account,
            program: ix.program,
            accounts: ix
                .accounts
                .into_iter()
                .map(|a| CallAccount {
                    account: a.account,
                    shard: None,
                    signer: a.signer,
                })
                .collect(),
            data: ix.data,
        };
        let engine = self.engine()?;
        let ticket = self
            .block(async { engine.request_tx(caller, relayed, intent).await })
            // The app's own proposal didn't build: tell it why.
            .map_err(|e| match policy::code_of(&e) {
                Code::Internal => coded(6104, format!("{e:#}"), Value::Null),
                _ => e,
            })?;
        if let Some(key) = key {
            let mut ids = lock(&self.ids);
            // Two identical proposals racing: the second is the duplicate.
            if let Some(handle) = ids.get(&key) {
                let _ = engine.reject(caller, &ticket.handle);
                return Err(coded(
                    5720,
                    "this proposal id was already used",
                    json!({ "handle": handle }),
                ));
            }
            ids.insert(key, ticket.handle.clone());
        }
        Ok(ticket)
    }

    /// Approve the open request. Answers once the wallet accepted it (a
    /// status change) or refused it (wrong password, stale, expired); the
    /// work itself (proving, inclusion) continues and is read by handle.
    fn approve(&'static self, p: &Value, caller: &Caller) -> Result<Value> {
        #[derive(Deserialize)]
        #[serde(rename_all = "camelCase")]
        struct P {
            handle: String,
            request_hash: String,
            #[serde(default)]
            password: Option<String>,
            #[serde(default)]
            acknowledged: bool,
        }
        let a: P = params(p)?;
        let password = a.password.map(Zeroizing::new);
        let engine = self.engine()?;
        let (tx, rx) = tokio::sync::oneshot::channel::<Result<TxStatus>>();
        let tx = Arc::new(Mutex::new(Some(tx)));
        let first = Arc::clone(&tx);
        let owner = caller.clone();
        let handle = a.handle.clone();
        self.detached("logos-kit-approve", move || async move {
            let mut progress = move |s: &TxStatus| {
                self.emit("request_updated", json!({ "handle": s.handle }));
                if let Some(t) = lock(&first).take() {
                    let _ = t.send(Ok(s.clone()));
                }
            };
            let done = engine
                .approve(
                    &owner,
                    &handle,
                    &a.request_hash,
                    password.as_ref().map(|p| p.as_str()),
                    a.acknowledged,
                    &mut progress,
                )
                .await;
            if let Err(e) = &done {
                // The status carries the error for the activity row.
                self.emit(
                    "request_updated",
                    json!({ "handle": handle, "error": policy::code_of(e) as i64 }),
                );
            }
            if let Some(t) = lock(&tx).take() {
                let _ = t.send(done);
            }
        });
        let first = self
            .rt
            .block_on(async { tokio::time::timeout(ACCEPT_WAIT, rx).await });
        let status = match first {
            Ok(Ok(Ok(s))) => s,
            Ok(Ok(Err(e))) => return Err(e),
            // Still working without a status change yet (a slow build): accepted.
            Ok(Err(_)) | Err(_) => self.engine()?.status(caller, &a.handle)?,
        };
        Ok(json!({ "accepted": true, "status": owner_status(&status) }))
    }

    fn sign_message(&self, p: &Value) -> Result<Value> {
        #[derive(Deserialize)]
        struct P {
            account: String,
            /// Base64 bytes.
            message: String,
        }
        let a: P = params(p)?;
        let bytes = STANDARD
            .decode(&a.message)
            .map_err(|_| invalid("message must be base64"))?;
        ensure!(
            bytes.len() <= message::MAX_MESSAGE,
            invalid("message is too long")
        );
        let hash = message::tagged_hash(message::MESSAGE_TAG, &bytes);
        let engine = self.engine()?;
        let (sig, pk) = self.block(async {
            engine
                .with_session(async |s| s.sign_prehash(&a.account, &hash))
                .await
        })?;
        Ok(json!({
            "signature": STANDARD.encode(sig),
            "publicKey": STANDARD.encode(pk),
            "tag": message::MESSAGE_TAG,
        }))
    }

    fn sign_in(&self, p: &Value) -> Result<Value> {
        #[derive(Deserialize)]
        struct P {
            requester: String,
            account: String,
            request: SignInRequest,
        }
        let a: P = params(p)?;
        check_requester(&a.requester)?;
        let chain = self.current_zone().chain;
        let text = a.request.text(&chain, &a.account)?;
        let hash = message::tagged_hash(message::SIGNIN_TAG, text.as_bytes());
        let engine = self.engine()?;
        let (sig, pk) = self.block(async {
            engine
                .with_session(async |s| s.sign_prehash(&a.account, &hash))
                .await
        })?;
        let caps = self
            .granted_caps(&a.requester, &a.account)
            .unwrap_or_default();
        Ok(json!({
            "account": {
                "address": a.account, "kind": "public", "chain": chain,
                "publicKey": STANDARD.encode(pk), "capabilities": caps,
            },
            "signedMessage": text,
            "signature": STANDARD.encode(sig),
        }))
    }

    fn request_funds(&'static self, p: &Value, caller: &Caller) -> Result<Value> {
        #[derive(Deserialize)]
        struct P {
            account: String,
            #[serde(default)]
            requester: Option<String>,
            #[serde(default)]
            via: Option<String>,
        }
        let a: P = params(p)?;
        if let Some(r) = &a.requester {
            check_requester(r)?;
        }
        let zone = self.current_zone();
        let url = lock(&self.prefs).faucets.get(&zone.id).cloned();
        let faucet = match (zone.id.as_str(), url) {
            (_, Some(url)) => Faucet::Http(HttpFaucet::new("Drip service", &url)?),
            ("lez-local", None) => Faucet::Key(Box::new(self.local_faucet(&zone)?)),
            _ => {
                return Err(coded(
                    6109,
                    "no faucet is set up for this network yet (Settings → Network)",
                    Value::Null,
                ));
            }
        };
        let engine = self.engine()?;
        let mut key = [0u8; 16];
        getrandom_fill(&mut key);
        let job = format!("job_{}", URL_SAFE_NO_PAD.encode(key));
        lock(&self.jobs).insert(
            job.clone(),
            json!({ "state": "running", "account": a.account }),
        );
        let owner = caller.clone();
        let id = job.clone();
        self.detached("logos-kit-faucet", move || async move {
            let request_key = hex::encode(key);
            let (relayed, via) = (a.requester.as_deref(), a.via.as_deref());
            let out = match &faucet {
                Faucet::Http(f) => {
                    engine
                        .request_funds(&owner, relayed, &a.account, via, f, &request_key)
                        .await
                }
                Faucet::Key(f) => {
                    engine
                        .request_funds(&owner, relayed, &a.account, via, &**f, &request_key)
                        .await
                }
            };
            let v = match out {
                Ok(f) => json!({ "state": "done", "account": a.account, "result": f }),
                Err(e) => json!({
                    "state": "error", "account": a.account,
                    "error": { "code": policy::code_of(&e) as i64, "message": format!("{e:#}") },
                }),
            };
            lock(&self.jobs).insert(id.clone(), v);
            self.emit("funds_updated", json!({ "job": id }));
            self.refresh.notify_one();
        });
        Ok(json!({ "job": job }))
    }

    /// Run `make()`'s future on its own thread, inside the runtime. The
    /// engine's futures hold async closures, which rustc can't yet prove
    /// `Send`, so they are built on the thread that polls them instead of
    /// being handed to `tokio::spawn`.
    fn detached<F, Fut>(&self, name: &str, make: F)
    where
        F: FnOnce() -> Fut + Send + 'static,
        Fut: Future<Output = ()>,
    {
        let rt = self.rt.handle().clone();
        let spawned = std::thread::Builder::new()
            .name(name.to_owned())
            .spawn(move || rt.block_on(make()));
        if let Err(e) = spawned {
            self.emit(
                "error",
                json!({ "message": format!("couldn't start {name}: {e}") }),
            );
        }
    }

    fn local_faucet(&self, zone: &Zone) -> Result<KeyFaucet> {
        KeyFaucet::new(
            "Local genesis key",
            &zone.sequencer,
            LOCAL_GENESIS_KEY,
            1_000_000_000,
            Duration::from_secs(20),
        )
    }

    // -- LWS-0 reads --------------------------------------------------------------

    fn read_account(&self, p: &Value) -> Result<Value> {
        #[derive(Deserialize)]
        struct P {
            chain: String,
            account: String,
            program: String,
        }
        let a: P = params(p)?;
        let zone = self.current_zone();
        if a.chain != zone.chain {
            return Err(coded(
                4902,
                format!("the wallet is on {}", zone.chain),
                Value::Null,
            ));
        }
        let id = crate::decode::account_id(&a.account).map_err(|_| invalid("bad account id"))?;
        let program =
            crate::decode::account_id(&a.program).map_err(|_| invalid("bad program id"))?;
        let client = self.client()?;
        self.block(async {
            let view = client
                .get_account_view(ProgramShardSelector::new(id, program))
                .await
                .map_err(|e| Denied::err(Code::ChainDisconnected, format!("{e}")))?;
            let nonce = client
                .get_accounts_nonces(vec![id])
                .await
                .map_err(|e| Denied::err(Code::ChainDisconnected, format!("{e}")))?
                .into_iter()
                .next()
                .unwrap_or_default();
            Ok(json!({
                "nonce": nonce.0.to_string(),
                "data": STANDARD.encode(view.data.shard(program).as_ref()),
            }))
        })
    }

    fn get_session(&self, caller: &Caller) -> Result<Value> {
        let app = app_of(caller)?;
        self.session_for(&app)
    }

    /// The LWS-0 `Session` of `app` in the current zone (null: not connected).
    fn session_for(&self, app: &str) -> Result<Value> {
        let accounts = self.granted_accounts(app)?;
        if accounts.as_array().is_none_or(Vec::is_empty) {
            return Ok(Value::Null);
        }
        let zone = self.current_zone();
        let id = Sha256::digest(format!("logos-kit/session/v1\0{}\0{app}", zone.id));
        Ok(json!({
            "sessionId": format!("ses_{}", URL_SAFE_NO_PAD.encode(&id[..18])),
            "origin": app,
            "chains": [zone.chain],
            "accounts": accounts,
            "capabilities": capabilities(),
        }))
    }

    fn granted_caps(&self, app: &str, account: &str) -> Result<Vec<Capability>> {
        let engine = self.locked_is_disconnected()?;
        self.block(async {
            engine
                .with_session_quiet(async |s| {
                    let zone = s.zone().id.clone();
                    Ok(s.grants()
                        .iter()
                        .filter(|g| g.zone == zone && g.requester == app && g.account == account)
                        .map(|g| g.capability)
                        .collect())
                })
                .await
        })
    }

    /// The engine, or LWS-0 4900 when the wallet is locked (apps see "disconnected").
    fn locked_is_disconnected(&self) -> Result<Arc<Engine>> {
        let engine = lock(&self.engine).clone();
        match engine {
            Some(e) if self.block(async { Ok(e.is_unlocked().await) })? => Ok(e),
            _ => Err(coded(4900, "the wallet is locked", Value::Null)),
        }
    }

    fn granted_accounts(&self, app: &str) -> Result<Value> {
        let engine = self.locked_is_disconnected()?;
        let chain = self.current_zone().chain;
        self.block(async {
            engine
                .with_session_quiet(async |s| {
                    let zone = s.zone().id.clone();
                    let mut by_account: Vec<(String, Vec<Capability>)> = Vec::new();
                    for g in s
                        .grants()
                        .iter()
                        .filter(|g| g.zone == zone && g.requester == app)
                    {
                        match by_account.iter_mut().find(|(a, _)| *a == g.account) {
                            Some((_, caps)) => caps.push(g.capability),
                            None => by_account.push((g.account.clone(), vec![g.capability])),
                        }
                    }
                    let mine = s.accounts()?;
                    let mut out = Vec::new();
                    for (account, caps) in by_account {
                        let Some(info) = mine.iter().find(|m| m.account_id == account) else {
                            continue;
                        };
                        out.push(match info.kind {
                            AccountKind::Public => json!({
                                "address": account, "kind": "public", "chain": chain,
                                "publicKey": STANDARD.encode(s.public_key(&account)?),
                                "capabilities": caps,
                            }),
                            AccountKind::Private => json!({
                                "address": private_handle(&zone, app, &account),
                                "kind": "private", "chain": chain, "capabilities": caps,
                            }),
                        });
                    }
                    Ok(Value::Array(out))
                })
                .await
        })
    }

    fn get_balance(&self, p: &Value, caller: &Caller) -> Result<Value> {
        #[derive(Deserialize)]
        struct P {
            chain: String,
            account: String,
            #[serde(default)]
            asset: Option<String>,
        }
        let a: P = params(p)?;
        let app = app_of(caller)?;
        let zone = self.current_zone();
        if a.chain != zone.chain {
            return Err(coded(
                4902,
                format!("the wallet is on {}", zone.chain),
                Value::Null,
            ));
        }
        let engine = self.locked_is_disconnected()?;
        let tip = lock(&self.snapshot).tip;
        self.block(async {
            engine
                .with_session_quiet(async |s| {
                    let zone_id = s.zone().id.clone();
                    let mine = s.accounts()?;
                    let (id, cap) = if a.account.starts_with("pvt_") {
                        let found = mine.iter().find(|m| {
                            m.kind == AccountKind::Private
                                && private_handle(&zone_id, &app, &m.account_id) == a.account
                        });
                        (found.map(|m| m.account_id.clone()), Capability::ReadPrivate)
                    } else {
                        (Some(a.account.clone()), Capability::ReadPublic)
                    };
                    let id = id.filter(|id| policy::allows(s.grants(), &zone_id, &app, id, cap));
                    let Some(id) = id else {
                        return Err(Denied::err(
                            Code::Unauthorized,
                            "this app can't read that account's balance",
                        ));
                    };
                    let amount = s.balance_of(&id, a.asset.as_deref()).await?;
                    let synced = !s.status()?.discovering;
                    let mut out = json!({
                        "asset": a.asset.clone().unwrap_or_else(|| "native".into()),
                        "amount": amount.to_string(),
                        "synced": synced,
                    });
                    if let Some(t) = tip {
                        out["asOfBlock"] = json!(t.to_string());
                    }
                    Ok(out)
                })
                .await
        })
    }

    // -- background ----------------------------------------------------------------

    async fn sync_once(&self, engine: &Engine) {
        struct Quiet;
        impl wallet::sync_observer::SyncObserver for Quiet {}
        let proving: Vec<TxStatus> = engine
            .statuses(&Caller::LocalOwner)
            .into_iter()
            .filter(|s| matches!(s.lifecycle, Lifecycle::Proving | Lifecycle::Signing))
            .collect();
        let result = engine
            .with_session_quiet(async |s| {
                let synced = s.sync(&mut Quiet).await;
                let holdings = s.holdings().await.unwrap_or_default();
                let mut accounts = Vec::new();
                for a in s.accounts()? {
                    let native = s.balance_of(&a.account_id, None).await.ok();
                    let tokens: Vec<&crate::tokens::Holding> = holdings
                        .iter()
                        .filter(|h| h.account == a.account_id)
                        .collect();
                    let busy = proving
                        .iter()
                        .any(|p| p.from.as_deref() == Some(a.account_id.as_str()));
                    accounts.push(json!({
                        "accountId": a.account_id,
                        "kind": a.kind,
                        "label": a.label,
                        "path": a.path,
                        "native": native.map(|n| n.to_string()),
                        "tokens": tokens,
                        "proofInProgress": busy,
                    }));
                }
                let status = s.status().ok();
                Ok((synced, accounts, status))
            })
            .await;
        let mut snap = lock(&self.snapshot);
        match result {
            Ok((synced, accounts, status)) => {
                snap.accounts = accounts;
                snap.updated_ms = now_ms();
                match synced {
                    Ok(tip) => {
                        snap.tip = Some(tip);
                        snap.error = None;
                    }
                    Err(e) => {
                        snap.error = Some(format!("{e:#}"));
                        if let Some(ZoneStatusTip(t)) = status.map(tip_of) {
                            snap.tip = Some(t);
                        }
                    }
                }
            }
            Err(e) => snap.error = Some(format!("{e:#}")),
        }
        drop(snap);
        self.emit("snapshot_updated", json!({}));
    }
}

enum Faucet {
    Http(HttpFaucet),
    Key(Box<KeyFaucet>),
}

struct ZoneStatusTip(u64);

fn tip_of(s: crate::session::ZoneStatus) -> ZoneStatusTip {
    ZoneStatusTip(match s.network {
        NetStatus::Online { tip } => tip,
        _ => s.synced_block,
    })
}

async fn background(svc: &'static Service, engine: Arc<Engine>, generation: u64) {
    let mut last_sync: Option<Instant> = None;
    loop {
        if *lock(&svc.generation) != generation {
            return;
        }
        if matches!(engine.tick().await, Ok(true)) || !engine.is_unlocked().await {
            *lock(&svc.snapshot) = Snapshot::default();
            svc.emit("wallet_changed", json!({ "locked": true }));
            return;
        }
        if last_sync.is_none_or(|t| t.elapsed() >= SYNC_EVERY) {
            svc.sync_once(&engine).await;
            last_sync = Some(Instant::now());
        }
        tokio::select! {
            () = tokio::time::sleep(TICK_EVERY) => {}
            () = svc.refresh.notified() => last_sync = None,
        }
    }
}

// -- helpers -----------------------------------------------------------------------

fn getrandom_fill(buf: &mut [u8]) {
    use chacha20poly1305::aead::{OsRng, rand_core::RngCore as _};
    OsRng.fill_bytes(buf);
}

fn app_of(caller: &Caller) -> Result<String> {
    match caller {
        Caller::Module(name) => Ok(name.clone()),
        _ => Err(Denied::err(
            Code::Unauthorized,
            "this caller has no app identity",
        )),
    }
}

fn check_requester(r: &str) -> Result<()> {
    ensure!(
        valid_module_name(r),
        invalid("requester must be a module name")
    );
    ensure!(
        r != WALLET_UI_MODULE,
        invalid("the wallet can't request from itself")
    );
    Ok(())
}

fn check_password(pw: &str) -> Result<()> {
    ensure!(
        pw.chars().count() >= 8,
        invalid("use at least 8 characters for the password")
    );
    Ok(())
}

/// Opaque per-app handle for a private account (LWS-0 §8.4 rule 4): two apps
/// never see the same handle, and a handle doesn't reveal the account.
fn private_handle(zone: &str, app: &str, account: &str) -> String {
    let h = Sha256::digest(format!("logos-kit/handle/v1\0{zone}\0{app}\0{account}"));
    format!("pvt_{}", URL_SAFE_NO_PAD.encode(&h[..16]))
}

/// Name the first accounts the way the first-run screen shows them.
fn name_defaults(s: &mut Session) -> Result<()> {
    let accounts = s.accounts()?;
    for (kind, name) in [
        (AccountKind::Public, "Public account 1"),
        (AccountKind::Private, "Private account 1"),
    ] {
        if let Some(a) = accounts
            .iter()
            .find(|a| a.kind == kind && a.label.is_none())
            && !accounts.iter().any(|x| x.label.as_deref() == Some(name))
        {
            s.set_label(&a.account_id, Some(name))?;
        }
    }
    Ok(())
}


/// A private account's receive code: `lezpriv1:` + base64url(npk ‖ vpk). The
/// viewing key is an ML-KEM-768 key (1,184 bytes), so the code is long; it
/// still fits one QR code at error correction L. The fingerprint is what
/// people compare out loud.
fn receive_code(npk: &str, vpk: &str) -> Value {
    let mut bytes = hex::decode(npk).unwrap_or_default();
    bytes.extend(hex::decode(vpk).unwrap_or_default());
    let code = format!("{RECEIVE_PREFIX}{}", URL_SAFE_NO_PAD.encode(&bytes));
    let h = Sha256::digest(&bytes);
    let fp: String = h[..4]
        .iter()
        .map(|b| CROCKFORD[usize::from(b & 31)] as char)
        .collect();
    json!({
        "kind": "private",
        "code": code,
        "fingerprint": format!("{}-{}", &fp[..2], &fp[2..]),
    })
}

const RECEIVE_PREFIX: &str = "lezpriv1:";
const CROCKFORD: &[u8; 32] = b"0123456789ABCDEFGHJKMNPQRSTVWXYZ";

/// Parse a receive code back into the recipient keys.
pub fn parse_receive_code(code: &str) -> Result<RecipientKeys> {
    let body = code
        .trim()
        .strip_prefix(RECEIVE_PREFIX)
        .context("not a Logos Kit private receive code (lezpriv1:…)")?;
    let bytes = URL_SAFE_NO_PAD
        .decode(body)
        .map_err(|_| anyhow::anyhow!("the receive code is damaged"))?;
    ensure!(bytes.len() > 64, "the receive code is incomplete");
    let (npk, vpk) = bytes.split_at(32);
    Ok(RecipientKeys {
        npk: hex::encode(npk),
        vpk: hex::encode(vpk),
        identifier: None,
    })
}

#[cfg(test)]
mod tests {
    #[test]
    fn receive_code_round_trips() {
        let npk = "11".repeat(32);
        let vpk = "22".repeat(1184);
        let v = super::receive_code(&npk, &vpk);
        let code = v["code"].as_str().unwrap();
        assert!(code.starts_with("lezpriv1:") && code.len() < 1700, "{}", code.len());
        let keys = super::parse_receive_code(code).unwrap();
        assert_eq!((keys.npk, keys.vpk), (npk, vpk));
        assert!(super::parse_receive_code("lezpriv1:AAAA").is_err());
    }
}

fn faucet_label(zone: &Zone, prefs: &Prefs) -> Option<&'static str> {
    if prefs.faucets.contains_key(&zone.id) {
        Some("Drip service")
    } else if zone.id == "lez-local" {
        Some("Local genesis key")
    } else {
        None
    }
}

/// Open an https link with the OS (the QML sandbox can't).
fn open_url(url: &str) -> Result<()> {
    ensure!(
        url.starts_with("https://")
            && url.len() <= 2048
            && !url.chars().any(|c| c.is_whitespace() || c.is_control()),
        invalid("only https links open")
    );
    #[cfg(target_os = "macos")]
    let opener = "open";
    #[cfg(not(target_os = "macos"))]
    let opener = "xdg-open";
    std::process::Command::new(opener)
        .arg(url)
        .spawn()
        .with_context(|| format!("couldn't run {opener}"))?;
    Ok(())
}

fn capabilities() -> Value {
    json!({
        "accountKinds": ["public", "private"],
        "signTransaction": false,
        "batch": { "maxInstructions": 1, "atomic": "unsupported" },
        "proving": { "location": "local", "typicalSeconds": ETA_SHIELD_S },
        "outcomeVerification": ["own-account-invariant"],
        "signMessage": true,
        "signIn": true,
        "requestFunds": true,
    })
}

fn eta(s: &TxStatus) -> Option<u64> {
    let total = match s.route? {
        Route::Shield => ETA_SHIELD_S,
        Route::Unshield | Route::Private => ETA_PRIVATE_S,
        Route::Public => return None,
    };
    let elapsed = now_ms().saturating_sub(s.phase_started_ms) / 1000;
    Some(total.saturating_sub(elapsed))
}

/// The wallet UI's view: everything, plus who asked and the proving ETA.
fn owner_status(s: &TxStatus) -> Value {
    let mut v = serde_json::to_value(s).unwrap_or(Value::Null);
    v["requester"] = json!(s.requester());
    v["nowMs"] = json!(now_ms());
    if s.lifecycle == Lifecycle::Proving {
        v["etaSeconds"] = json!(eta(s));
        v["etaTotalSeconds"] = json!(match s.route {
            Some(Route::Shield) => ETA_SHIELD_S,
            _ => ETA_PRIVATE_S,
        });
    }
    v
}

/// LWS-0 `TransactionStatus` for apps.
fn protocol_status(s: &TxStatus, caller: &Caller) -> Value {
    let mut v = json!({
        "handle": s.handle,
        "chain": s.chain,
        "lifecycle": s.lifecycle,
        "outcome": s.outcome,
        "outcomeSource": s.outcome_source,
    });
    if let Some(h) = &s.tx_hash {
        v["txHash"] = json!(h);
    }
    if let Some(b) = s.block {
        v["block"] = json!({ "id": b.to_string() });
    }
    let private = s.route.is_some_and(Route::is_private);
    let phase = match s.lifecycle {
        Lifecycle::Building => Some("preparing"),
        Lifecycle::Proving => Some("proving"),
        Lifecycle::Signing => Some("submitting"),
        Lifecycle::Submitted => Some("waiting_for_block"),
        _ => None,
    };
    if let (true, Some(phase)) = (private, phase) {
        let mut proving = json!({ "phase": phase });
        if let Some(e) = eta(s).filter(|_| s.lifecycle == Lifecycle::Proving) {
            proving["etaSeconds"] = json!(e);
        }
        v["proving"] = proving;
    }
    if let Some(code) = s.error_code {
        let message = if caller.is_owner() {
            s.error.clone().unwrap_or_default()
        } else {
            default_copy(code).to_owned()
        };
        v["error"] = json!({ "code": code, "message": message });
    }
    v
}

fn default_copy(code: i64) -> &'static str {
    match code {
        4001 => "Request declined",
        4100 => "This app isn't connected to that account",
        6102 => "Proof failed: nothing was sent",
        6103 => "The sequencer rejected the transaction",
        6106 => "Something changed since you approved. Please review again",
        6107 => "A request is already open in your wallet",
        6108 => "Sent, not seen in a block yet",
        _ => "The transaction didn't go through",
    }
}
