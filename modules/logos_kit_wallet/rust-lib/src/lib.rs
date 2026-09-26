//! Logos Kit wallet core module.
//!
//! S0 skeleton: proves the toolchain end to end (build → .lgx → Basecamp →
//! `logos.callModuleAsync`). The real API (LWS-0 `lez_*` methods, `ui_*`
//! approval methods, `request_updated` events) arrives in S3/S7 and delegates
//! to `crates/wallet-engine`, which this shim reaches through its C ABI
//! (`libwallet_engine`, linked by the builder as an external library).

// The engine's C ABI (crates/wallet-engine/include/wallet_engine.h). Only the
// shim calls it, so the S3 policy layer sits between callers and the engine.
// Paths are fully qualified: the generated glue (provider_gen.rs) already
// imports `c_char`/`CStr` into this module.
extern "C" {
    fn lk_engine_info() -> *mut std::ffi::c_char;
    fn lk_engine_free(s: *mut std::ffi::c_char);
}

/// Take ownership of an engine-returned string.
fn engine_string(ptr: *mut std::ffi::c_char) -> String {
    if ptr.is_null() {
        return r#"{"ok":false,"error":{"code":-32603,"message":"engine returned null"}}"#.to_string();
    }
    // SAFETY: the engine returns a valid NUL-terminated string it owns until
    // lk_engine_free, which we call exactly once right after copying.
    let out = unsafe { std::ffi::CStr::from_ptr(ptr) }.to_string_lossy().into_owned();
    unsafe { lk_engine_free(ptr) };
    out
}

/// The module contract. The trait name must be the PascalCase module name
/// plus `Module` (builder convention).
pub trait LogosKitWalletModule: Send + 'static {
    /// Health check used by S0 exit criteria and the identity-hop probe.
    fn ping(&mut self) -> String;

    /// Returns the caller identity as seen by this module (`current_caller()`),
    /// as JSON. Used by the S0 identity-hop probe.
    fn whoami(&mut self) -> String;

    /// Engine build info (`{"ok":true,"result":{"engine","lezRev"}}`): proves
    /// the LEZ engine is linked and callable from Basecamp.
    fn engine_info(&mut self) -> String;

    fn on_context_ready(&mut self, _ctx: &RustModuleContext) {}
}

/// Typed events. Each method becomes an `emit_<name>` function.
pub trait LogosKitWalletModuleEvents {
    fn pinged(&self, caller: String);
}

include!(concat!(env!("CARGO_MANIFEST_DIR"), "/generated/provider_gen.rs"));

#[derive(Default)]
struct Wallet;

fn caller_json() -> String {
    logos_rust_sdk::current_caller_json().unwrap_or_else(|| "null".to_string())
}

impl LogosKitWalletModule for Wallet {
    fn ping(&mut self) -> String {
        // Events reach every subscriber, so they never carry caller identity.
        emit_pinged("{\"ok\":true}");
        serde_json::json!({ "ok": true, "module": "logos_kit_wallet", "version": env!("CARGO_PKG_VERSION") })
            .to_string()
    }

    fn whoami(&mut self) -> String {
        caller_json()
    }

    fn engine_info(&mut self) -> String {
        // SAFETY: plain C call with no arguments; the result is handed to engine_string.
        engine_string(unsafe { lk_engine_info() })
    }
}

#[no_mangle]
pub extern "Rust" fn logos_module_install() {
    install::<Wallet>();
}
