//! JSON dispatch shared by the C ABI and (later) the CLI.
//!
//! S1 exposes `info` (and `derivePublicAccounts` in test builds only); keystore, sync, approvals and
//! proving methods land in S2–S4 behind the same dispatcher.

use serde_json::{Value, json};

pub fn ok(result: Value) -> Value {
    json!({ "ok": true, "result": result })
}

pub fn err(code: i64, message: &str) -> Value {
    json!({ "ok": false, "error": { "code": code, "message": message } })
}

pub fn info() -> Value {
    json!({ "engine": env!("CARGO_PKG_VERSION"), "lezRev": crate::LEZ_REV })
}

#[cfg(test)]
/// The first `count` public accounts of a mnemonic, in the official wallet's
/// layered order (same derivation as `lez/wallet`, empty passphrase).
fn derive_public_accounts(params: &Value) -> Value {
    use key_protocol::key_management::{key_tree::KeyTreePublic, secret_holders::SeedHolder};

    let Some(phrase) = params.get("mnemonic").and_then(Value::as_str) else {
        return err(-32602, "mnemonic is required");
    };
    let count = params
        .get("count")
        .and_then(Value::as_u64)
        .unwrap_or(1)
        .clamp(1, 20);
    let Ok(mnemonic) = bip39::Mnemonic::parse(phrase) else {
        return err(-32602, "invalid recovery phrase");
    };
    let mut tree = KeyTreePublic::new(&SeedHolder::from_mnemonic(&mnemonic, ""));
    let accounts: Vec<Value> = (0..count)
        .filter_map(|_| tree.generate_new_public_node_layered())
        .map(|(id, path)| json!({ "path": path.to_string(), "accountId": id.to_string() }))
        .collect();
    ok(json!({ "accounts": accounts }))
}

pub fn dispatch(request: &str) -> Value {
    let Ok(req) = serde_json::from_str::<Value>(request) else {
        return err(-32700, "request is not JSON");
    };
    #[cfg(test)]
    let params = req.get("params").cloned().unwrap_or(Value::Null);
    match req.get("method").and_then(Value::as_str) {
        Some("info") => ok(info()),
        // Takes a recovery phrase, so test builds only: keys never cross the C ABI.
        #[cfg(test)]
        Some("derivePublicAccounts") => derive_public_accounts(&params),
        Some(_) => err(-32601, "unknown method"),
        None => err(-32600, "method is required"),
    }
}
