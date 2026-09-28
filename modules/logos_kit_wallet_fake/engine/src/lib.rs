//! A deterministic stand-in for the Logos Kit wallet engine (conformance kit).
//!
//! Same C ABI as `crates/wallet-engine` (`include/wallet_engine.h`), so the
//! real core-module shim links it unchanged and the conformance runner loads
//! it with ctypes. It holds no keys and talks to no chain: every answer comes
//! from the active scenario (`SCENARIOS`), so a dApp sees the same wallet
//! behaviour on every run.
//!
//! - LWS-0 methods (`lez_*`) answer like the real wallet: sessions per
//!   `(app, chain)`, grants, error codes (4100, 4902, 5730, 6109…).
//! - Intents (connect, send, sign, sign in, faucet) are answered by
//!   `ui_fakeIntent`, which the fake's provider UI (or the runner) calls with
//!   what the shell delivered. The answer carries the shell's error code
//!   string and an optional `delayMs` before it is delivered.
//! - Every call and intent is logged (`ui_fakeLog`, and
//!   `<dataDir>/fake-calls.jsonl` when a data dir is set) so a runner can
//!   check what the dApp did.
//! - Scenario: `{"scenario"}` in the init config, else
//!   `LOGOS_KIT_FAKE_SCENARIO`, else `happy`; `ui_fakeSetScenario` switches
//!   it and resets state. `ui_*` methods answer any caller: this is a test
//!   tool, never a wallet.

use std::{
    collections::{BTreeMap, HashSet},
    ffi::{CStr, CString, c_char},
    io::Write as _,
    path::PathBuf,
    sync::{Mutex, MutexGuard},
};

use serde_json::{Value, json};
use sha2::{Digest as _, Sha256};

/// What each scenario does, for docs, the capability matrix and the runner.
pub const SCENARIOS: &[(&str, &str)] = &[
    (
        "happy",
        "Connect shares one public account (and a private handle if asked). Balance 1000000000. \
         A send answers a handle; status reads go submitted → included/success. The faucet funds 1000000000.",
    ),
    (
        "reject",
        "The user declines every wallet prompt: each intent answers `cancelled` (LWS-0 4001).",
    ),
    (
        "timeout",
        "Like happy, but the send intent answers only after 50 s: the SDK times out at 45 s \
         (6108) and the handle arrives late (`onLateResult`).",
    ),
    (
        "stale",
        "The send is approved, then the chain moved: status goes signing → dropped with error 6106 \
         (StaleApproval). Nothing was sent.",
    ),
    (
        "unknown_outcome",
        "The send is included but the wallet can't tell whether it worked: included, outcome \
         `unknown`, outcomeSource `none`.",
    ),
    (
        "failed_onchain",
        "The send is included and failed on chain: included, outcome `failure` \
         (own-account-invariant).",
    ),
    (
        "rate_limited",
        "Balance 0. The faucet refuses: `rate_limited`, retryAfterSeconds 60. Everything else is happy.",
    ),
    (
        "faucet_unknown",
        "Balance 0. The faucet answer is lost: `outcome_unknown`. The funds do arrive (balance \
         +1000000000), so a dApp that re-reads the balance finds them.",
    ),
    (
        "no_funds",
        "Balance 0. A send is refused by the wallet (intent answers `failed`, as in every \
         scenario while the account is empty); the faucet funds 1000000000, after which sends work.",
    ),
    (
        "network_switch",
        "After the first connect, the user switches the wallet to lez:local: the next lez_chainId \
         answers lez:local, the old session is gone and calls naming the old chain get 4902.",
    ),
    (
        "unavailable",
        "The wallet is not running: every method answers 6109, every intent `unavailable`.",
    ),
];

const BASE_CHAIN: &str = "lez:testnet";
const SWITCHED_CHAIN: &str = "lez:local";
const START_BALANCE: u128 = 1_000_000_000;
const FAUCET_DROP: u128 = 1_000_000_000;
const LATE_MS: u64 = 50_000;

struct Tx {
    app: String,
    /// Status answers in order; reads past the end repeat the last.
    plan: Vec<Value>,
    reads: usize,
}

struct State {
    scenario: String,
    chain: String,
    data_dir: Option<PathBuf>,
    /// (app, chain) → shared accounts.
    sessions: BTreeMap<(String, String), Vec<Value>>,
    balances: BTreeMap<String, u128>,
    txs: BTreeMap<String, Tx>,
    ids: HashSet<(String, String)>,
    connected_once: bool,
    seq: u64,
    log: Vec<Value>,
    events: Vec<Value>,
}

impl State {
    fn new(scenario: String, data_dir: Option<PathBuf>) -> Self {
        Self {
            scenario,
            chain: BASE_CHAIN.to_owned(),
            data_dir,
            sessions: BTreeMap::new(),
            balances: BTreeMap::new(),
            txs: BTreeMap::new(),
            ids: HashSet::new(),
            connected_once: false,
            seq: 0,
            log: Vec::new(),
            events: Vec::new(),
        }
    }

    fn is(&self, s: &str) -> bool {
        self.scenario == s
    }

    fn balance(&self, account: &str) -> u128 {
        // The faucet scenarios start empty, so a dApp offers its faucet step.
        let empty = ["no_funds", "rate_limited", "faucet_unknown"];
        let start = if empty.contains(&self.scenario.as_str()) {
            0
        } else {
            START_BALANCE
        };
        *self.balances.get(account).unwrap_or(&start)
    }

    fn record(&mut self, entry: Value) {
        self.seq += 1;
        let mut e = entry;
        e["seq"] = json!(self.seq);
        e["scenario"] = json!(self.scenario);
        e["chain"] = json!(self.chain);
        if let Some(dir) = &self.data_dir
            && let Ok(mut f) = std::fs::OpenOptions::new()
                .create(true)
                .append(true)
                .open(dir.join("fake-calls.jsonl"))
        {
            let _ = writeln!(f, "{e}");
        }
        self.log.push(e);
    }
}

static STATE: Mutex<Option<State>> = Mutex::new(None);

fn state() -> MutexGuard<'static, Option<State>> {
    STATE
        .lock()
        .unwrap_or_else(std::sync::PoisonError::into_inner)
}

fn default_scenario() -> String {
    std::env::var("LOGOS_KIT_FAKE_SCENARIO").unwrap_or_else(|_| "happy".to_owned())
}

// -- ids ---------------------------------------------------------------------------

fn digest(parts: &[&str]) -> [u8; 32] {
    let mut h = Sha256::new();
    h.update(b"logos-kit/fake/v1");
    for p in parts {
        h.update((p.len() as u64).to_le_bytes());
        h.update(p.as_bytes());
    }
    h.finalize().into()
}

fn base58(bytes: &[u8]) -> String {
    const ALPHABET: &[u8] = b"123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";
    let mut digits: Vec<u8> = Vec::new();
    for &b in bytes {
        let mut carry = u32::from(b);
        for d in &mut digits {
            carry += u32::from(*d) << 8;
            *d = (carry % 58) as u8;
            carry /= 58;
        }
        while carry > 0 {
            digits.push((carry % 58) as u8);
            carry /= 58;
        }
    }
    let zeros = bytes.iter().take_while(|&&b| b == 0).count();
    let mut out = "1".repeat(zeros);
    out.extend(digits.iter().rev().map(|&d| ALPHABET[d as usize] as char));
    out
}

fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}

fn b64(bytes: &[u8]) -> String {
    const T: &[u8] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    let mut out = String::new();
    for c in bytes.chunks(3) {
        let n = (u32::from(c[0]) << 16)
            | (u32::from(*c.get(1).unwrap_or(&0)) << 8)
            | u32::from(*c.get(2).unwrap_or(&0));
        for i in 0..4 {
            if i <= c.len() {
                out.push(T[((n >> (18 - 6 * i)) & 63) as usize] as char);
            } else {
                out.push('=');
            }
        }
    }
    out
}

/// The fake's public account (valid base58 of 32 bytes).
pub fn public_account() -> String {
    base58(&digest(&["account", "public", "1"]))
}

/// Another valid account nobody owns (a recipient for test sends).
pub fn other_account() -> String {
    base58(&digest(&["account", "other", "1"]))
}

fn private_handle(app: &str) -> String {
    let d = digest(&["private", app]);
    format!("pvt_{}", &hex(&d)[..24])
}

fn tx_hash(handle: &str) -> String {
    format!("0x{}", hex(&digest(&["tx", handle])))
}

fn capabilities() -> Value {
    json!({
        "accountKinds": ["public", "private"],
        "signTransaction": false,
        "batch": { "maxInstructions": 1, "atomic": "unsupported" },
        "proving": { "location": "local", "typicalSeconds": 270 },
        "outcomeVerification": ["own-account-invariant"],
        "signMessage": true,
        "signIn": true,
        "requestFunds": true,
    })
}

// -- answers -----------------------------------------------------------------------

fn err(code: i64, message: &str) -> Value {
    json!({ "ok": false, "error": { "code": code, "message": message } })
}

fn ok(v: Value) -> Value {
    json!({ "ok": true, "result": v })
}

fn app_of(caller: &Value) -> Option<String> {
    caller
        .get("name")
        .and_then(Value::as_str)
        .filter(|n| !n.is_empty())
        .map(str::to_owned)
}

fn str_param<'a>(p: &'a Value, k: &str) -> Option<&'a str> {
    p.get(k).and_then(Value::as_str)
}

fn session_json(s: &State, app: &str) -> Value {
    match s.sessions.get(&(app.to_owned(), s.chain.clone())) {
        Some(accounts) => json!({
            "sessionId": format!("ses_fake_{}", &hex(&digest(&["session", app, &s.chain]))[..24]),
            "origin": app,
            "chains": [s.chain],
            "accounts": accounts,
            "capabilities": capabilities(),
        }),
        None => Value::Null,
    }
}

fn granted(s: &State, app: &str, account: &str) -> bool {
    s.sessions
        .get(&(app.to_owned(), s.chain.clone()))
        .is_some_and(|a| a.iter().any(|x| x["address"] == account))
}

fn status_of(handle: &str, chain: &str, lifecycle: &str, outcome: &str, source: &str) -> Value {
    let mut v = json!({
        "handle": handle,
        "chain": chain,
        "lifecycle": lifecycle,
        "outcome": outcome,
        "outcomeSource": source,
    });
    if matches!(lifecycle, "submitted" | "included" | "finalized") {
        v["txHash"] = json!(tx_hash(handle));
        v["fee"] = json!({ "estimatedMax": "134400000" });
    }
    if matches!(lifecycle, "included" | "finalized") {
        v["block"] = json!({ "id": "42" });
        v["fee"]["used"] = json!("96000");
    }
    v
}

/// The status answers a send goes through in this scenario.
fn tx_plan(s: &State, handle: &str) -> Vec<Value> {
    let c = s.chain.as_str();
    match s.scenario.as_str() {
        "stale" => {
            let mut dropped = status_of(handle, c, "dropped", "unknown", "none");
            dropped["error"] = json!({
                "code": 6106,
                "message": "Something changed since you approved. Please review again"
            });
            vec![status_of(handle, c, "signing", "unknown", "none"), dropped]
        }
        "unknown_outcome" => vec![
            status_of(handle, c, "submitted", "unknown", "none"),
            status_of(handle, c, "included", "unknown", "none"),
        ],
        "failed_onchain" => vec![
            status_of(handle, c, "submitted", "unknown", "none"),
            status_of(handle, c, "included", "failure", "own-account-invariant"),
        ],
        _ => vec![
            status_of(handle, c, "submitted", "unknown", "none"),
            status_of(handle, c, "included", "success", "own-account-invariant"),
        ],
    }
}

fn new_handle(s: &mut State, app: &str) -> String {
    let n = s.txs.len() + 1;
    let handle = format!(
        "fake_{n:04}_{}",
        &hex(&digest(&["handle", app, &n.to_string()]))[..16]
    );
    let plan = tx_plan(s, &handle);
    s.txs.insert(
        handle.clone(),
        Tx {
            app: app.to_owned(),
            plan,
            reads: 0,
        },
    );
    s.events
        .push(json!({ "event": "request_updated", "handle": handle }));
    handle
}

/// A proposal the wallet would accept, or the LWS-0 error it refuses with.
fn check_proposal(s: &mut State, app: &str, p: &Value) -> Result<(), Value> {
    let chain = str_param(p, "chain").unwrap_or("");
    if chain != s.chain {
        return Err(err(4902, &format!("the wallet is on {}", s.chain)));
    }
    let account = str_param(p, "account").unwrap_or("");
    if !granted(s, app, account) {
        return Err(err(4100, "this app isn't connected to that account"));
    }
    let n = p
        .get("instructions")
        .and_then(Value::as_array)
        .map_or(0, Vec::len);
    if n == 0 {
        return Err(err(6104, "a proposal needs one instruction"));
    }
    if n > 1 {
        return Err(err(
            5740,
            "this wallet runs one instruction per transaction",
        ));
    }
    if let Some(id) = str_param(p, "id")
        && !s.ids.insert((app.to_owned(), id.to_owned()))
    {
        return Err(err(5720, "duplicate request id"));
    }
    Ok(())
}

// -- LWS-0 methods ------------------------------------------------------------------

fn lws(s: &mut State, method: &str, p: &Value, app: &str) -> Value {
    if s.is("unavailable") {
        return err(6109, "the wallet isn't available");
    }
    match method {
        "lez_getCapabilities" => ok(capabilities()),
        "lez_chainId" => {
            if s.is("network_switch") && s.connected_once && s.chain == BASE_CHAIN {
                s.chain = SWITCHED_CHAIN.to_owned();
                s.events
                    .push(json!({ "event": "wallet_changed", "chain": SWITCHED_CHAIN }));
            }
            ok(json!({ "chain": s.chain }))
        }
        "lez_getSession" => ok(session_json(s, app)),
        "lez_getAccounts" => ok(json!(
            s.sessions
                .get(&(app.to_owned(), s.chain.clone()))
                .cloned()
                .unwrap_or_default()
        )),
        "lez_getBalance" => {
            if str_param(p, "chain") != Some(s.chain.as_str()) {
                return err(4902, &format!("the wallet is on {}", s.chain));
            }
            let account = str_param(p, "account").unwrap_or("");
            if !granted(s, app, account) {
                return err(4100, "this app can't read that account's balance");
            }
            ok(json!({
                "asset": str_param(p, "asset").unwrap_or("native"),
                "amount": s.balance(account).to_string(),
                "synced": true,
                "asOfBlock": "42",
            }))
        }
        "lez_readAccount" => {
            if str_param(p, "chain") != Some(s.chain.as_str()) {
                return err(4902, &format!("the wallet is on {}", s.chain));
            }
            if str_param(p, "account").is_none() || str_param(p, "program").is_none() {
                return err(-32602, "account and program are required");
            }
            // Chain state isn't simulated: every account is empty.
            ok(json!({ "nonce": "0", "data": "" }))
        }
        "lez_openExplorer" => {
            let target = str_param(p, "txHash")
                .or_else(|| str_param(p, "account"))
                .unwrap_or("");
            if target.is_empty() {
                return err(-32602, "name a txHash or an account");
            }
            ok(json!({ "url": format!("https://explorer.invalid/fake/{target}") }))
        }
        "lez_getTransactionStatus" => {
            let handle = str_param(p, "handle").unwrap_or("");
            let Some(tx) = s.txs.get_mut(handle).filter(|t| t.app == app) else {
                return err(5730, "unknown transaction handle");
            };
            let i = tx.reads.min(tx.plan.len() - 1);
            tx.reads += 1;
            ok(tx.plan[i].clone())
        }
        "lez_disconnect" => {
            s.sessions.remove(&(app.to_owned(), s.chain.clone()));
            ok(Value::Null)
        }
        "lez_connect" => {
            let silent = p.get("silent").and_then(Value::as_bool) == Some(true);
            match session_json(s, app) {
                v if silent && !v.is_null() => ok(v),
                _ => err(4100, "connect through the lez.wallet.connect intent"),
            }
        }
        "lez_signAndSendTransaction" => {
            // A module proposing directly: the fake approves per scenario.
            if let Err(e) = check_proposal(s, app, p) {
                return e;
            }
            if s.is("reject") {
                return err(4001, "Request declined");
            }
            let handle = new_handle(s, app);
            ok(json!({ "handle": handle }))
        }
        "lez_signMessage" | "lez_signIn" | "lez_requestFunds" | "lez_switchChain" => {
            err(4200, &format!("{method} needs the user: use its Basecamp intent"))
        }
        // Same answer as the real wallet: an unknown method teaches nothing.
        _ => err(4100, "unknown method"),
    }
}

// -- intents (what the fake's provider answers) ------------------------------------

/// `{ok, data?, error?, delayMs?}`: the provider's answer to the shell.
fn intent(s: &mut State, name: &str, p: &Value, app: &str) -> Value {
    let no = |code: &str| json!({ "ok": false, "error": code });
    if s.is("unavailable") {
        return no("unavailable");
    }
    if s.is("reject") {
        return no("cancelled");
    }
    match name {
        "lez.wallet.connect" => {
            let chains: Vec<&str> = p
                .get("chains")
                .and_then(Value::as_array)
                .map(|c| c.iter().filter_map(Value::as_str).collect())
                .unwrap_or_default();
            if !chains.contains(&s.chain.as_str()) {
                // The wallet shows "switch network first" and closes: `failed`.
                return no("failed");
            }
            let kinds: Vec<&str> = p
                .get("accountKinds")
                .and_then(Value::as_array)
                .map(|c| c.iter().filter_map(Value::as_str).collect())
                .unwrap_or_default();
            let caps = ["accounts", "read_public", "propose_tx"];
            let mut accounts = Vec::new();
            if kinds.is_empty() || kinds.contains(&"public") {
                accounts.push(json!({
                    "address": public_account(),
                    "kind": "public",
                    "chain": s.chain,
                    "publicKey": b64(&digest(&["pubkey", "1"])),
                    "label": "Fake public",
                    "capabilities": caps,
                }));
            }
            if kinds.contains(&"private") {
                accounts.push(json!({
                    "address": private_handle(app),
                    "kind": "private",
                    "chain": s.chain,
                    "label": "Fake private",
                    "capabilities": ["accounts", "read_private", "propose_tx"],
                }));
            }
            s.sessions
                .insert((app.to_owned(), s.chain.clone()), accounts);
            s.connected_once = true;
            json!({ "ok": true, "data": session_json(s, app) })
        }
        "lez.transaction.send" => {
            if check_proposal(s, app, p).is_err() {
                return no("failed");
            }
            let account = str_param(p, "account").unwrap_or("");
            if s.balance(account) == 0 {
                // The review shows "not enough LEZ"; the user can only close it.
                return no("failed");
            }
            let handle = new_handle(s, app);
            let mut a = json!({ "ok": true, "data": { "handle": handle } });
            if s.is("timeout") {
                a["delayMs"] = json!(LATE_MS);
            }
            a
        }
        "lez.wallet.request_funds" => {
            let account = str_param(p, "account").unwrap_or("").to_owned();
            if str_param(p, "chain") != Some(s.chain.as_str()) || !granted(s, app, &account) {
                return no("failed");
            }
            match s.scenario.as_str() {
                "rate_limited" => json!({
                    "ok": true,
                    "data": { "status": "rate_limited", "retryAfterSeconds": 60 }
                }),
                other => {
                    let after = s.balance(&account) + FAUCET_DROP;
                    s.balances.insert(account.clone(), after);
                    let n = s.balances.len().to_string();
                    let data = if other == "faucet_unknown" {
                        json!({ "status": "outcome_unknown" })
                    } else {
                        json!({
                            "status": "funded",
                            "amount": FAUCET_DROP.to_string(),
                            "txHash": tx_hash(&format!("faucet{account}{n}")),
                            "fundedAccount": if account.starts_with("pvt_") { json!(public_account()) } else { json!(account) },
                        })
                    };
                    s.events
                        .push(json!({ "event": "funds_updated", "account": account }));
                    json!({ "ok": true, "data": data })
                }
            }
        }
        "lez.message.sign" => {
            let account = str_param(p, "account").unwrap_or("");
            if !granted(s, app, account) || account.starts_with("pvt_") {
                return no("failed");
            }
            let msg = str_param(p, "message").unwrap_or("");
            let sig = [digest(&["sig", msg]), digest(&["sig2", msg])].concat();
            json!({ "ok": true, "data": {
                "signature": b64(&sig),
                "publicKey": b64(&digest(&["pubkey", "1"])),
                "tag": "LEZ/message/v1",
            }})
        }
        "lez.wallet.sign_in" => {
            let domain = str_param(p, "domain").unwrap_or("");
            let nonce = str_param(p, "nonce").unwrap_or("");
            if domain.is_empty() || nonce.len() < 8 {
                return no("bad_request");
            }
            let account = json!({
                "address": public_account(),
                "kind": "public",
                "chain": s.chain,
                "publicKey": b64(&digest(&["pubkey", "1"])),
                "capabilities": ["accounts", "read_public", "propose_tx"],
            });
            s.sessions
                .insert((app.to_owned(), s.chain.clone()), vec![account.clone()]);
            s.connected_once = true;
            let message = format!(
                "{domain} wants you to sign in with your LEZ account:\n{}\n\nNonce: {nonce}",
                public_account()
            );
            let sig = [
                digest(&["signin", &message]),
                digest(&["signin2", &message]),
            ]
            .concat();
            json!({ "ok": true, "data": {
                "account": account, "signedMessage": message, "signature": b64(&sig)
            }})
        }
        _ => no("bad_request"),
    }
}

fn dispatch(req: &Value) -> Value {
    let method = req.get("method").and_then(Value::as_str).unwrap_or("");
    let p = req.get("params").cloned().unwrap_or(Value::Null);
    let p = if p.is_null() { json!({}) } else { p };
    let caller = req.get("caller").cloned().unwrap_or(Value::Null);
    let mut guard = state();
    let s = guard.get_or_insert_with(|| State::new(default_scenario(), None));

    if let Some(ui) = method.strip_prefix("ui_") {
        return match ui {
            "fakeIntent" => {
                let name = str_param(&p, "intent").unwrap_or("").to_owned();
                let app = str_param(&p, "requester").unwrap_or("").to_owned();
                let params = p.get("params").cloned().unwrap_or(json!({}));
                let answer = intent(s, &name, &params, &app);
                s.record(json!({
                    "kind": "intent", "name": name, "app": app,
                    "params": params, "answer": answer,
                }));
                ok(answer)
            }
            "fakeSetScenario" => {
                let name = str_param(&p, "scenario").unwrap_or("");
                if !SCENARIOS.iter().any(|(n, _)| *n == name) {
                    return err(-32602, &format!("unknown scenario {name}"));
                }
                *s = State::new(name.to_owned(), s.data_dir.clone());
                ok(json!({ "scenario": name }))
            }
            "fakeScenarios" => ok(json!(
                SCENARIOS
                    .iter()
                    .map(|(n, d)| json!({ "name": n, "description": d }))
                    .collect::<Vec<_>>()
            )),
            "fakeLog" => {
                let since = p.get("since").and_then(Value::as_u64).unwrap_or(0);
                ok(json!(
                    s.log
                        .iter()
                        .filter(|e| e["seq"].as_u64().unwrap_or(0) > since)
                        .cloned()
                        .collect::<Vec<_>>()
                ))
            }
            "fakeState" => ok(json!({
                "scenario": s.scenario,
                "chain": s.chain,
                "publicAccount": public_account(),
                "otherAccount": other_account(),
                "handles": s.txs.keys().collect::<Vec<_>>(),
            })),
            _ => err(4200, "unknown method"),
        };
    }

    let app = app_of(&caller).unwrap_or_default();
    let answer = if app.is_empty() {
        err(4100, "no caller identity")
    } else {
        lws(s, method, &p, &app)
    };
    s.record(json!({
        "kind": "call", "method": method, "app": app,
        "params": p,
        "answer": if answer["ok"] == true { json!({ "ok": true, "value": answer["result"] }) }
                  else { json!({ "ok": false, "code": answer["error"]["code"] }) },
    }));
    answer
}

// -- C ABI ---------------------------------------------------------------------------

fn out(v: &Value) -> *mut c_char {
    CString::new(v.to_string()).unwrap_or_default().into_raw()
}

fn input(ptr: *const c_char) -> Option<Value> {
    if ptr.is_null() {
        return None;
    }
    // SAFETY: the caller passes a live NUL-terminated string (header contract).
    let s = unsafe { CStr::from_ptr(ptr) }.to_str().ok()?;
    serde_json::from_str(s).ok()
}

fn guarded(f: impl FnOnce() -> Value + std::panic::UnwindSafe) -> *mut c_char {
    let v = std::panic::catch_unwind(f).unwrap_or_else(|_| err(-32603, "fake engine panicked"));
    out(&v)
}

#[unsafe(no_mangle)]
pub extern "C" fn lk_engine_info() -> *mut c_char {
    out(&ok(
        json!({ "engine": "fake-0.1.0", "lezRev": "fake", "fake": true }),
    ))
}

/// # Safety
/// `config_json` must be a valid NUL-terminated UTF-8 string, or null.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn lk_engine_init(config_json: *const c_char) -> *mut c_char {
    let config = input(config_json).unwrap_or(json!({}));
    guarded(move || {
        let scenario = config
            .get("scenario")
            .and_then(Value::as_str)
            .map_or_else(default_scenario, str::to_owned);
        let dir = config
            .get("dataDir")
            .and_then(Value::as_str)
            .map(PathBuf::from);
        let mut g = state();
        match g.as_mut() {
            // Idempotent, like the real engine (the shim calls it once per process).
            Some(s) => {
                if s.data_dir.is_none() {
                    s.data_dir = dir;
                }
            }
            None => *g = Some(State::new(scenario, dir)),
        }
        ok(json!({ "started": true, "fake": true }))
    })
}

/// # Safety
/// `request_json` must be a valid NUL-terminated UTF-8 string, or null.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn lk_engine_call(request_json: *const c_char) -> *mut c_char {
    match input(request_json) {
        Some(req) => guarded(move || dispatch(&req)),
        None => out(&err(-32600, "request must be JSON")),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn lk_engine_events() -> *mut c_char {
    let mut g = state();
    let events = g
        .as_mut()
        .map(|s| std::mem::take(&mut s.events))
        .unwrap_or_default();
    out(&json!(events))
}

/// # Safety
/// `s` must be a pointer returned by this library, freed at most once.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn lk_engine_free(s: *mut c_char) {
    if !s.is_null() {
        // SAFETY: `s` came from CString::into_raw in this library.
        drop(unsafe { CString::from_raw(s) });
    }
}
