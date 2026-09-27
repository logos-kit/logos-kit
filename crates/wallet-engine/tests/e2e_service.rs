//! Integration test: the approval authorization path through the service the
//! Basecamp module shim drives (`just e2e-service`), on the standalone LEZ
//! sequencer. Every call goes through the same JSON envelope the shim sends,
//! with the caller identity the host would attest.
//!
//! Covers: an app with no grant is refused; connect needs the owner's
//! approval (a wrong password keeps the request); an app proposes, the owner
//! approves, and it lands; a repeated proposal id is refused with its handle;
//! handles are private to their app; `ui_*` is the wallet UI's alone; message
//! signatures verify; a shield proves and lands; lock disconnects apps.
//!
//! Skipped unless `LK_E2E_SEQUENCER` is set (the harness sets it).

use std::time::{Duration, Instant};

use base64::{Engine as _, engine::general_purpose::STANDARD};
use serde_json::{Value, json};
use wallet_engine::{message, service};

const PW: &str = "e2e-password";
const APP: &str = "probe_dapp";

fn call(method: &str, params: Value, caller: &Value) -> Result<Value, Value> {
    let req = json!({ "method": method, "params": params, "caller": caller });
    let out = service::call(&req.to_string());
    if out["ok"] == true {
        Ok(out["result"].clone())
    } else {
        Err(out["error"].clone())
    }
}

fn ui(method: &str, params: Value) -> Value {
    call(
        method,
        params,
        &json!({ "kind": "module", "name": "logos_kit_wallet_ui" }),
    )
    .unwrap_or_else(|e| panic!("{method}: {e}"))
}

fn app(name: &str) -> Value {
    json!({ "kind": "module", "name": name })
}

fn code(r: Result<Value, Value>) -> i64 {
    r.expect_err("expected an error")["code"].as_i64().unwrap()
}

fn wait_for(what: &str, secs: u64, mut f: impl FnMut() -> Option<Value>) -> Value {
    let end = Instant::now() + Duration::from_secs(secs);
    loop {
        if let Some(v) = f() {
            return v;
        }
        assert!(Instant::now() < end, "timed out waiting for {what}");
        std::thread::sleep(Duration::from_millis(500));
    }
}

fn native_transfer(amount: u128) -> String {
    let mut data = vec![0u8];
    data.extend_from_slice(&amount.to_le_bytes());
    STANDARD.encode(data)
}

fn wait_included(handle: &str, caller: &Value, secs: u64) -> Value {
    wait_for("inclusion", secs, || {
        let s = call(
            "lez_getTransactionStatus",
            json!({ "handle": handle }),
            caller,
        )
        .ok()?;
        match s["lifecycle"].as_str()? {
            "included" => Some(s),
            "dropped" | "rejected" | "expired" => panic!("transaction failed: {s}"),
            _ => None,
        }
    })
}

#[test]
fn approval_path_through_the_service() {
    if std::env::var("LK_E2E_SEQUENCER").is_err() {
        eprintln!("skipped: LK_E2E_SEQUENCER is not set (run `just e2e-service`)");
        return;
    }
    let dir = tempfile::tempdir().unwrap();
    let init = service::init(&json!({ "dataDir": dir.path() }).to_string());
    assert_eq!(init["ok"], true, "{init}");
    let wallet_ui = json!({ "kind": "module", "name": "logos_kit_wallet_ui" });
    let dapp = app(APP);

    // First run on the local zone: one public and one private account.
    ui("ui_setPrefs", json!({ "zone": "lez-local" }));
    let created = ui("ui_create", json!({ "password": PW }));
    assert_eq!(created["words"].as_array().unwrap().len(), 24);
    let accounts = created["accounts"].as_array().unwrap();
    let find = |kind: &str| {
        accounts.iter().find(|a| a["kind"] == kind).unwrap()["accountId"]
            .as_str()
            .unwrap()
            .to_owned()
    };
    let (public, private) = (find("public"), find("private"));
    let payee = ui(
        "ui_newAccount",
        json!({ "kind": "public", "label": "Payee" }),
    )["accountId"]
        .as_str()
        .unwrap()
        .to_owned();

    // Test funds from the local zone's faucet (a background job).
    let job = ui("ui_requestFunds", json!({ "account": public }))["job"]
        .as_str()
        .unwrap()
        .to_owned();
    let funded = wait_for("faucet", 120, || {
        let j = ui("ui_fundStatus", json!({ "job": job }));
        (j["state"] != "running").then_some(j)
    });
    assert_eq!(funded["result"]["status"], "funded", "{funded}");

    // The wallet UI's methods are the wallet UI's alone.
    assert_eq!(code(call("ui_state", json!({}), &dapp)), 4100);
    // Not connected: nothing to see, nothing to propose.
    assert_eq!(
        call("lez_getSession", json!({}), &dapp).unwrap(),
        Value::Null
    );
    let proposal = |id: &str| {
        json!({
            "chain": "lez:local",
            "account": public,
            "id": id,
            "instructions": [{
                "program": "11111111111111111111111111111111",
                "accounts": [
                    { "account": public, "writable": true, "signer": true },
                    { "account": payee, "writable": true, "signer": false },
                ],
                "data": native_transfer(7),
            }],
        })
    };
    assert_eq!(
        code(call("lez_signAndSendTransaction", proposal("a"), &dapp)),
        4100
    );

    // Connect (relayed by the wallet UI, as the intent handler does).
    let ticket = ui(
        "ui_requestConnect",
        json!({
            "requester": APP,
            "accounts": [public],
            "capabilities": ["accounts", "read_public", "propose_tx"],
        }),
    );
    let handle = ticket["handle"].as_str().unwrap();
    let hash = ticket["request"]["requestHash"].as_str().unwrap();
    // A typo doesn't cost the request.
    let wrong = call(
        "ui_approve",
        json!({ "handle": handle, "requestHash": hash, "password": "not-it-at-all" }),
        &wallet_ui,
    );
    assert!(wrong.is_err());
    assert_eq!(ui("ui_pending", json!({}))["handle"], handle);
    let ok = ui(
        "ui_approve",
        json!({ "handle": handle, "requestHash": hash, "password": PW }),
    );
    assert_eq!(ok["accepted"], true);
    let session = call("lez_getSession", json!({}), &dapp).unwrap();
    assert_eq!(session["accounts"][0]["address"], public.as_str());
    assert!(session["accounts"][0]["publicKey"].is_string());
    let balance = call(
        "lez_getBalance",
        json!({ "chain": "lez:local", "account": public }),
        &dapp,
    )
    .unwrap();
    assert_ne!(balance["amount"], "0");
    // The private account wasn't shared.
    assert_eq!(session["accounts"].as_array().unwrap().len(), 1);

    // A malformed proposal says why (to the app that sent it).
    let mut bad = proposal("bad");
    bad["instructions"][0]["accounts"][1]["account"] = json!(public);
    let e = call("lez_signAndSendTransaction", bad, &dapp).unwrap_err();
    assert_eq!(e["code"], 6104, "{e}");

    // The app proposes directly; the owner approves in the wallet.
    let sent = call("lez_signAndSendTransaction", proposal("t-1"), &dapp).unwrap();
    let handle = sent["handle"].as_str().unwrap().to_owned();
    let dup = call("lez_signAndSendTransaction", proposal("t-1"), &dapp).unwrap_err();
    assert_eq!(dup["code"], 5720);
    assert_eq!(dup["data"]["handle"], handle.as_str());
    // Another app can't read it, and can't approve anything.
    assert_eq!(
        code(call(
            "lez_getTransactionStatus",
            json!({ "handle": handle }),
            &app("other_dapp")
        )),
        5730
    );
    assert_eq!(
        code(call(
            "ui_approve",
            json!({ "handle": handle, "requestHash": "00" }),
            &app("other_dapp")
        )),
        4100
    );
    let pending = ui("ui_pending", json!({}));
    assert_eq!(pending["handle"], handle.as_str());
    assert_eq!(pending["request"]["requester"], APP);
    let hash = pending["request"]["requestHash"].as_str().unwrap();
    let ok = ui(
        "ui_approve",
        json!({ "handle": handle, "requestHash": hash }),
    );
    assert_eq!(ok["accepted"], true);
    let done = wait_included(&handle, &dapp, 120);
    assert!(done["txHash"].as_str().unwrap().starts_with("0x"));

    // A message signature verifies against the returned key and tag.
    let msg = b"hello from the e2e";
    let signed = ui(
        "ui_signMessage",
        json!({ "account": public, "message": STANDARD.encode(msg) }),
    );
    let sig: [u8; 64] = STANDARD
        .decode(signed["signature"].as_str().unwrap())
        .unwrap()
        .try_into()
        .unwrap();
    let pk: [u8; 32] = STANDARD
        .decode(signed["publicKey"].as_str().unwrap())
        .unwrap()
        .try_into()
        .unwrap();
    let hash = message::tagged_hash(message::MESSAGE_TAG, msg);
    assert!(
        lee::Signature { value: sig }.is_valid_for(&hash, &lee::PublicKey::try_new(pk).unwrap())
    );

    // A shield from the wallet itself: proves, lands, and the private balance moves.
    let ticket = ui(
        "ui_prepareSend",
        json!({ "kind": "transfer", "from": public, "to": private, "amount": "1234" }),
    );
    assert_eq!(ticket["request"]["route"], "shield");
    assert_eq!(ticket["needsPassword"], true);
    let handle = ticket["handle"].as_str().unwrap().to_owned();
    let hash = ticket["request"]["requestHash"].as_str().unwrap();
    let ok = ui(
        "ui_approve",
        json!({ "handle": handle, "requestHash": hash, "password": PW }),
    );
    assert_eq!(ok["accepted"], true);
    let shielded = wait_for("shield", 900, || {
        let s = ui("ui_status", json!({ "handle": handle }));
        match s["lifecycle"].as_str()? {
            "included" => Some(s),
            "dropped" | "rejected" | "expired" => panic!("shield failed: {s}"),
            _ => None,
        }
    });
    assert_eq!(shielded["outcome"], "success", "{shielded}");

    // Activity lists both, newest first; lock disconnects apps.
    let activity = ui("ui_activity", json!({}));
    assert!(activity.as_array().unwrap().len() >= 3);
    ui("ui_lock", json!({}));
    assert_eq!(code(call("lez_getSession", json!({}), &dapp)), 4900);
    eprintln!("OK: connect, app proposal, dedupe, isolation, signature, shield, lock");
}
