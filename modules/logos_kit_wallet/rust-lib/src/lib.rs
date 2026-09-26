//! Logos Kit wallet core module.
//!
//! S0 skeleton: proves the toolchain end to end (build → .lgx → Basecamp →
//! `logos.callModuleAsync`). The real API (LWS-0 `lez_*` methods, `ui_*`
//! approval methods, `request_updated` events) arrives in S3/S7 and delegates
//! to `crates/wallet-engine`.

/// The module contract. The trait name must be the PascalCase module name
/// plus `Module` (builder convention).
pub trait LogosKitWalletModule: Send + 'static {
    /// Health check used by S0 exit criteria and the identity-hop probe.
    fn ping(&mut self) -> String;

    /// Returns the caller identity as seen by this module (`current_caller()`),
    /// as JSON. Used by the S0 identity-hop probe.
    fn whoami(&mut self) -> String;

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
}

#[no_mangle]
pub extern "Rust" fn logos_module_install() {
    install::<Wallet>();
}
