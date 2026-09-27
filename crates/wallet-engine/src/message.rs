//! Off-chain signatures: `lez_signMessage` and `lez_signIn`.
//!
//! Both sign a BIP-340 *tagged hash* (`SHA256(SHA256(tag) ‖ SHA256(tag) ‖ msg)`)
//! with a public account's key. The tag keeps a message signature from ever
//! being a valid transaction signature: LEZ signs its message hash directly.
//! - `LEZ/message/v1` over the raw message bytes;
//! - `LEZ/signin/v1` over the UTF-8 of the SIWE-shaped text below.

use anyhow::{Result, ensure};
use serde::Deserialize;
use sha2::{Digest as _, Sha256};

pub const MESSAGE_TAG: &str = "LEZ/message/v1";
pub const SIGNIN_TAG: &str = "LEZ/signin/v1";
/// Largest message the wallet signs (the intent payload cap is 64 KB of base64).
pub const MAX_MESSAGE: usize = 48 * 1024;

/// BIP-340 tagged hash.
pub fn tagged_hash(tag: &str, msg: &[u8]) -> [u8; 32] {
    let t = Sha256::digest(tag.as_bytes());
    let mut h = Sha256::new();
    h.update(t);
    h.update(t);
    h.update(msg);
    h.finalize().into()
}

/// `lez_signIn` request (protocol `SignInRequest`).
#[derive(Clone, Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SignInRequest {
    pub domain: String,
    #[serde(default)]
    pub statement: Option<String>,
    pub uri: String,
    pub nonce: String,
    pub issued_at: String,
    #[serde(default)]
    pub expiration_time: Option<String>,
    #[serde(default)]
    pub not_before: Option<String>,
    #[serde(default)]
    pub request_id: Option<String>,
}

fn one_line(field: &str, v: &str, max: usize) -> Result<()> {
    ensure!(
        !v.is_empty() && v.len() <= max,
        "{field} must be 1–{max} characters"
    );
    // A newline would let a field forge another line of the signed text.
    ensure!(
        !v.chars().any(char::is_control),
        "{field} must be a single line"
    );
    Ok(())
}

impl SignInRequest {
    fn check(&self) -> Result<()> {
        one_line("domain", &self.domain, 253)?;
        one_line("uri", &self.uri, 2048)?;
        one_line("issuedAt", &self.issued_at, 64)?;
        ensure!(
            (8..=64).contains(&self.nonce.len())
                && self.nonce.bytes().all(|b| b.is_ascii_alphanumeric()),
            "nonce must be 8–64 letters or digits"
        );
        if let Some(s) = &self.statement {
            one_line("statement", s, 512)?;
        }
        for (f, v) in [
            ("expirationTime", &self.expiration_time),
            ("notBefore", &self.not_before),
            ("requestId", &self.request_id),
        ] {
            if let Some(v) = v {
                one_line(f, v, 64)?;
            }
        }
        Ok(())
    }

    /// The exact text that is signed (EIP-4361 layout, LEZ chain and account).
    pub fn text(&self, chain: &str, account: &str) -> Result<String> {
        self.check()?;
        let mut t = format!(
            "{} wants you to sign in with your LEZ account:\n{account}\n",
            self.domain
        );
        if let Some(s) = &self.statement {
            t.push('\n');
            t.push_str(s);
            t.push('\n');
        }
        t.push_str(&format!(
            "\nURI: {}\nVersion: 1\nChain ID: {chain}\nNonce: {}\nIssued At: {}",
            self.uri, self.nonce, self.issued_at
        ));
        if let Some(v) = &self.expiration_time {
            t.push_str(&format!("\nExpiration Time: {v}"));
        }
        if let Some(v) = &self.not_before {
            t.push_str(&format!("\nNot Before: {v}"));
        }
        if let Some(v) = &self.request_id {
            t.push_str(&format!("\nRequest ID: {v}"));
        }
        Ok(t)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn tagged_hash_matches_bip340_construction() {
        // BIP-340's own tag: SHA256(SHA256("BIP0340/challenge")×2 ‖ "") is fixed.
        let h = tagged_hash("BIP0340/challenge", b"");
        let t = Sha256::digest(b"BIP0340/challenge");
        let mut want = Sha256::new();
        want.update(t);
        want.update(t);
        assert_eq!(h, <[u8; 32]>::from(want.finalize()));
        assert_ne!(
            tagged_hash(MESSAGE_TAG, b"x"),
            tagged_hash(SIGNIN_TAG, b"x")
        );
    }

    #[test]
    fn signin_text_refuses_injected_lines() {
        let mut r = SignInRequest {
            domain: "example.app".into(),
            statement: Some("Welcome".into()),
            uri: "https://example.app".into(),
            nonce: "abcdefgh1".into(),
            issued_at: "2026-09-27T10:00:00Z".into(),
            expiration_time: None,
            not_before: None,
            request_id: None,
        };
        let t = r.text("lez:testnet", "Acct").unwrap();
        assert!(t.starts_with("example.app wants you to sign in with your LEZ account:\nAcct\n\nWelcome\n\nURI: https://example.app\nVersion: 1\nChain ID: lez:testnet\nNonce: abcdefgh1\nIssued At: 2026-09-27T10:00:00Z"));
        r.statement = Some("hi\nURI: https://evil".into());
        assert!(r.text("lez:testnet", "Acct").is_err());
    }
}
