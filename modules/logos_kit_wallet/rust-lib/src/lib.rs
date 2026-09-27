//! Logos Kit wallet core module: the shim between Basecamp and the engine.
//!
//! Every method forwards to the engine's C ABI (`libwallet_engine`, linked by
//! the builder as an external library) as `{"method", "params", "caller"}`,
//! where `caller` is what the host attests (`current_caller()`) and the app's
//! JSON only ever lands in `params`. The engine is the policy authority.
//!
//! Answers are the JSON text `{"value": <result>}` or
//! `{"error": {"code", "message", "data"?}}` (what `@logos-kit/client`'s
//! `basecampModule` transport reads). Events queued by the engine are emitted
//! here, on the dispatch thread, at the start of every call.

// The engine's C ABI (crates/wallet-engine/include/wallet_engine.h). Paths are
// fully qualified: the generated glue (provider_gen.rs) already imports
// `c_char`/`CStr` into this module.
extern "C" {
    fn lk_engine_info() -> *mut std::ffi::c_char;
    fn lk_engine_init(config_json: *const std::ffi::c_char) -> *mut std::ffi::c_char;
    fn lk_engine_call(request_json: *const std::ffi::c_char) -> *mut std::ffi::c_char;
    fn lk_engine_events() -> *mut std::ffi::c_char;
    fn lk_engine_free(s: *mut std::ffi::c_char);
}

const NULL_ANSWER: &str = r#"{"ok":false,"error":{"code":-32603,"message":"engine returned null"}}"#;

/// Take ownership of an engine-returned string.
fn engine_string(ptr: *mut std::ffi::c_char) -> String {
    if ptr.is_null() {
        return NULL_ANSWER.to_string();
    }
    // SAFETY: the engine returns a valid NUL-terminated string it owns until
    // lk_engine_free, which we call exactly once right after copying.
    let out = unsafe { std::ffi::CStr::from_ptr(ptr) }
        .to_string_lossy()
        .into_owned();
    unsafe { lk_engine_free(ptr) };
    out
}

fn with_c(json: &str, f: impl FnOnce(*const std::ffi::c_char) -> *mut std::ffi::c_char) -> String {
    match std::ffi::CString::new(json) {
        Ok(c) => engine_string(f(c.as_ptr())),
        Err(_) => r#"{"ok":false,"error":{"code":-32600,"message":"NUL in request"}}"#.to_string(),
    }
}

/// `{"ok":true,"result":v}` → `{"value":v}`; `{"ok":false,"error":e}` → `{"error":e}`.
/// Returned as a JSON value (LIDL `any`): the QML bridge serializes it once,
/// where a `String` would reach `callModuleAsync` as an encoded string literal.
fn answer(engine_json: &str) -> serde_json::Value {
    let v: serde_json::Value = serde_json::from_str(engine_json).unwrap_or_else(|_| {
        serde_json::json!({ "ok": false, "error": { "code": -32603, "message": "bad engine answer" } })
    });
    if v.get("ok").and_then(serde_json::Value::as_bool) == Some(true) {
        serde_json::json!({ "value": v.get("result").cloned().unwrap_or(serde_json::Value::Null) })
    } else {
        serde_json::json!({ "error": v.get("error").cloned().unwrap_or(serde_json::Value::Null) })
    }
}

/// Emit whatever the engine queued (request updates, lock, snapshots).
fn flush_events() {
    // SAFETY: plain C call; the result is handed to engine_string.
    let raw = engine_string(unsafe { lk_engine_events() });
    let Ok(serde_json::Value::Array(events)) = serde_json::from_str::<serde_json::Value>(&raw) else {
        return;
    };
    for e in events {
        let name = e.get("event").and_then(serde_json::Value::as_str).unwrap_or("");
        match name {
            "request_updated" | "request_opened" => {
                if let Some(h) = e.get("handle").and_then(serde_json::Value::as_str) {
                    emit_request_updated(h);
                }
            }
            _ => emit_wallet_event(name, &e.to_string()),
        }
    }
}

// The trait `LogosKitWalletModule` and the `emit_*` functions are generated
// from logos_kit_wallet.lidl (contract-first: the LWS-0 wire names are
// camelCase, which a Rust-first trait can't express).
include!(concat!(env!("CARGO_MANIFEST_DIR"), "/generated/provider_gen.rs"));

/// `concurrency: "multi"`: every call runs on its own worker, so a status
/// read never waits behind an approval. The engine is thread-safe; the only
/// shim state is whether the service started.
#[derive(Default)]
struct Wallet {
    started: std::sync::Mutex<bool>,
}

fn caller_json() -> String {
    logos_rust_sdk::current_caller_json().unwrap_or_else(|| "null".to_string())
}

impl Wallet {
    /// Start the engine service on the module's data directory (once).
    fn start(&self) -> Option<serde_json::Value> {
        let mut started = self
            .started
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner);
        if *started {
            return None;
        }
        let dir = match context() {
            Some(c) if !c.instance_persistence_path.is_empty() => c.instance_persistence_path,
            _ => {
                return Some(serde_json::json!({
                    "error": { "code": 6109, "message": "the wallet has no data directory yet" }
                }))
            }
        };
        let config = serde_json::json!({ "dataDir": dir }).to_string();
        // SAFETY: with_c passes a live NUL-terminated string for the call's duration.
        let out = with_c(&config, |c| unsafe { lk_engine_init(c) });
        let ok = serde_json::from_str::<serde_json::Value>(&out)
            .ok()
            .and_then(|v| v.get("ok").and_then(serde_json::Value::as_bool))
            == Some(true);
        if ok {
            *started = true;
            None
        } else {
            Some(answer(&out))
        }
    }

    fn forward(&self, method: &str, params: &str) -> serde_json::Value {
        // Read the identity first: it is valid only on this dispatch.
        let caller = caller_json();
        if let Some(err) = self.start() {
            return err;
        }
        let params: serde_json::Value = match serde_json::from_str(params) {
            Ok(v) => v,
            Err(_) if params.trim().is_empty() => serde_json::json!({}),
            Err(_) => {
                return serde_json::json!({
                    "error": { "code": -32602, "message": "params must be JSON" }
                })
            }
        };
        let caller: serde_json::Value =
            serde_json::from_str(&caller).unwrap_or(serde_json::Value::Null);
        let request =
            serde_json::json!({ "method": method, "params": params, "caller": caller }).to_string();
        // SAFETY: with_c passes a live NUL-terminated string for the call's duration.
        let out = with_c(&request, |c| unsafe { lk_engine_call(c) });
        flush_events();
        answer(&out)
    }
}

impl LogosKitWalletModule for Wallet {
    fn ping(&self) -> String {
        serde_json::json!({ "ok": true, "module": "logos_kit_wallet", "version": env!("CARGO_PKG_VERSION") })
            .to_string()
    }

    fn whoami(&self) -> String {
        caller_json()
    }

    fn engine_info(&self) -> String {
        // SAFETY: plain C call with no arguments; the result is handed to engine_string.
        engine_string(unsafe { lk_engine_info() })
    }

    fn lez_connect(&self, params: String) -> serde_json::Value {
        self.forward("lez_connect", &params)
    }
    fn lez_disconnect(&self, params: String) -> serde_json::Value {
        self.forward("lez_disconnect", &params)
    }
    fn lez_get_session(&self, params: String) -> serde_json::Value {
        self.forward("lez_getSession", &params)
    }
    fn lez_get_accounts(&self, params: String) -> serde_json::Value {
        self.forward("lez_getAccounts", &params)
    }
    fn lez_get_capabilities(&self, params: String) -> serde_json::Value {
        self.forward("lez_getCapabilities", &params)
    }
    fn lez_get_balance(&self, params: String) -> serde_json::Value {
        self.forward("lez_getBalance", &params)
    }
    fn lez_read_account(&self, params: String) -> serde_json::Value {
        self.forward("lez_readAccount", &params)
    }
    fn lez_sign_and_send_transaction(&self, params: String) -> serde_json::Value {
        self.forward("lez_signAndSendTransaction", &params)
    }
    fn lez_get_transaction_status(&self, params: String) -> serde_json::Value {
        self.forward("lez_getTransactionStatus", &params)
    }
    fn lez_sign_message(&self, params: String) -> serde_json::Value {
        self.forward("lez_signMessage", &params)
    }
    fn lez_sign_in(&self, params: String) -> serde_json::Value {
        self.forward("lez_signIn", &params)
    }
    fn lez_request_funds(&self, params: String) -> serde_json::Value {
        self.forward("lez_requestFunds", &params)
    }
    fn lez_switch_chain(&self, params: String) -> serde_json::Value {
        self.forward("lez_switchChain", &params)
    }

    fn ui(&self, method: String, params: String) -> serde_json::Value {
        // Only `ui_*` names; the engine checks the caller.
        let valid = !method.is_empty()
            && method.len() <= 32
            && method.bytes().all(|b| b.is_ascii_alphanumeric());
        if !valid {
            return serde_json::json!({ "error": { "code": -32601, "message": "unknown method" } });
        }
        self.forward(&format!("ui_{method}"), &params)
    }
}

#[no_mangle]
pub extern "Rust" fn logos_module_install() {
    install::<Wallet>();
}
