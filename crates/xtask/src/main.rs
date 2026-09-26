//! Repo automation. `cargo xtask <command>`.
//!
//! Commands:
//! - `fingerprint [url]`: identify the LEZ protocol version a sequencer runs.
//!   There is no version RPC; v0.3 exposes `getFeeState`, v0.2.x has `pinata`
//!   in `getProgramIds`.
//! - `vectors`: regenerate `protocol/vectors/*.json` from LEZ code (see vectors.rs).

mod vectors;

use std::{path::Path, time::Duration};

use anyhow::{Context, Result, bail};
use serde_json::{Value, json};

/// LEZ revision the vectors come from; must match the workspace `rev` pins.
pub const LEZ_REV: &str = "f7fda38a4428b9989f1db1dbf5d2411484848fd4";

const DEFAULT_SEQUENCER: &str = "https://testnet.lez.logos.co";

fn main() -> Result<()> {
    let args: Vec<String> = std::env::args().skip(1).collect();
    match args.first().map(String::as_str) {
        Some("fingerprint") => {
            let url = args.get(1).map_or(DEFAULT_SEQUENCER, String::as_str);
            fingerprint(url)
        }
        Some("vectors") => {
            let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("../..");
            vectors::run(&root)
        }
        _ => {
            eprintln!("usage: cargo xtask <fingerprint [sequencer-url] | vectors>");
            std::process::exit(2);
        }
    }
}

/// JSON-RPC call. Returns `Ok(Err(error_object))` for protocol-level errors
/// (e.g. "Method not found") so callers can use them as signals.
fn rpc(
    agent: &ureq::Agent,
    url: &str,
    method: &str,
    params: Value,
) -> Result<Result<Value, Value>> {
    let body = json!({ "jsonrpc": "2.0", "id": 1, "method": method, "params": params });
    let mut res = agent
        .post(url)
        .send_json(&body)
        .with_context(|| format!("POST {url} {method}"))?;
    let v: Value = res
        .body_mut()
        .read_json()
        .context("decode JSON-RPC response")?;
    if let Some(err) = v.get("error") {
        return Ok(Err(err.clone()));
    }
    match v.get("result") {
        Some(r) => Ok(Ok(r.clone())),
        None => bail!("malformed JSON-RPC response for {method}: {v}"),
    }
}

fn fingerprint(url: &str) -> Result<()> {
    let config = ureq::Agent::config_builder()
        .timeout_global(Some(Duration::from_secs(15)))
        .user_agent("logos-kit-xtask/0.1")
        .build();
    let agent: ureq::Agent = config.into();

    let fee_state = rpc(&agent, url, "getFeeState", json!([]))?;
    let program_ids = rpc(&agent, url, "getProgramIds", json!([]))?;
    let last_block = rpc(&agent, url, "getLastBlockId", json!([]))?;

    let program_names: Vec<String> = match &program_ids {
        Ok(Value::Object(map)) => map.keys().cloned().collect(),
        _ => vec![],
    };
    let has_pinata = program_names.iter().any(|n| n.contains("pinata"));

    let version = match (&fee_state, has_pinata) {
        (Ok(_), _) => "0.3",
        (Err(_), true) => "0.2.x",
        (Err(_), false) => "unknown",
    };

    let report = json!({
        "sequencer": url,
        "version": version,
        "lastBlockId": last_block.as_ref().ok(),
        "programs": program_names,
        "feeState": fee_state.as_ref().ok(),
        "feeStateError": fee_state.as_ref().err(),
    });
    println!("{}", serde_json::to_string_pretty(&report)?);
    Ok(())
}
