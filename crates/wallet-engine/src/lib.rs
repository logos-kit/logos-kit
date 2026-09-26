//! Logos Kit wallet engine.
//!
//! S1 linked the LEZ v0.3 wallet stack; S2 adds the keystore, sessions,
//! zones, sync and auto-lock. Policy, approvals and proving arrive in S3–S4
//! (see docs/dev/PLAN.md).

pub mod api;
pub mod auto_lock;
pub mod engine;
pub mod ffi;
pub mod policy;
pub mod session;
pub mod tx;
pub mod vault;

/// LEZ revision this engine is built against (see docs/dev/pins.md).
pub const LEZ_REV: &str = "f7fda38a4428b9989f1db1dbf5d2411484848fd4";

#[cfg(test)]
mod tests {
    #[test]
    fn links_lez_crates() {
        // Touch a type from each crate so the link is real.
        let _ = std::any::type_name::<wallet::WalletCore>();
        let _ = std::any::type_name::<lee_core::account::Account>();
        assert_eq!(super::LEZ_REV.len(), 40);
    }

    #[test]
    fn dispatch_derives_the_vector_accounts() {
        let out = super::api::dispatch(
            r#"{"method":"derivePublicAccounts","params":{"mnemonic":"abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about","count":3}}"#,
        );
        let paths: Vec<&str> = out["result"]["accounts"]
            .as_array()
            .unwrap()
            .iter()
            .map(|a| a["path"].as_str().unwrap())
            .collect();
        assert_eq!(paths, ["/0", "/1", "/0/0"]);
        assert_eq!(super::api::dispatch("nope")["error"]["code"], -32700);
    }
}
