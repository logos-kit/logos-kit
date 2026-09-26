//! Logos Kit wallet engine.
//!
//! S1 scope: link the LEZ v0.3 wallet stack at the pinned rev. Keystore,
//! policy, approvals and proving arrive in S2–S4 (see docs/dev/PLAN.md).

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
}
