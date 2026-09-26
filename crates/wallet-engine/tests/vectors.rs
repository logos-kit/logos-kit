//! Integration-confidence test #1 (docs/dev/PLAN.md): the committed
//! `protocol/vectors/*.json` still agree with LEZ at the pinned rev.
//!
//! `cargo xtask vectors` *encodes* with LEZ; this test *decodes* the committed
//! bytes with LEZ and re-verifies them, so a LEZ re-pin that changes the wire
//! format or key derivation fails here until the vectors are regenerated.

use std::{fs, path::PathBuf};

use base64::{Engine as _, engine::general_purpose::STANDARD as B64};
use common::transaction::LeeTransaction;
use key_protocol::key_management::{key_tree::KeyTreePublic, secret_holders::SeedHolder};
use lee::{PublicTransaction, public_transaction::Message};
use serde_json::Value;

fn load(name: &str) -> Value {
    let path = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("../../protocol/vectors")
        .join(name);
    serde_json::from_str(&fs::read_to_string(&path).expect("vectors present")).expect("valid JSON")
}

fn hex_field(v: &Value, key: &str) -> Vec<u8> {
    hex::decode(v[key].as_str().expect(key)).expect(key)
}

#[test]
fn vectors_rev_matches_engine() {
    for name in ["public_tx.json", "keys.json"] {
        assert_eq!(
            load(name)["meta"]["lezRev"],
            wallet_engine::LEZ_REV,
            "{name}: regenerate vectors"
        );
    }
}

#[test]
fn vectors_public_messages_roundtrip() {
    let v = load("public_tx.json");
    let signed = v["signed"].as_array().unwrap();
    for case in v["messages"].as_array().unwrap().iter().chain(signed) {
        let bytes = hex_field(case, "borsh");
        let msg: Message = borsh::from_slice(&bytes).expect("LEZ decodes the message");
        assert_eq!(borsh::to_vec(&msg).unwrap(), bytes, "{}", case["name"]);
        assert_eq!(
            msg.hash().to_vec(),
            hex_field(case, "hash"),
            "{}",
            case["name"]
        );
    }
}

#[test]
fn vectors_signed_transfer_verifies() {
    for case in load("public_tx.json")["signed"].as_array().unwrap() {
        let tx_json = &case["transaction"];
        let tx: PublicTransaction = borsh::from_slice(&hex_field(tx_json, "borsh")).unwrap();
        assert!(
            tx.witness_set().is_valid_for(tx.message()),
            "signature must verify"
        );
        assert_eq!(tx.hash().to_vec(), hex_field(tx_json, "hash"));

        let wire = B64
            .decode(case["rpc"]["sendTransactionParam"].as_str().unwrap())
            .unwrap();
        let wire_tx: LeeTransaction = borsh::from_slice(&wire).unwrap();
        assert!(matches!(&wire_tx, LeeTransaction::Public(t) if *t == tx));
        assert_eq!(
            wire_tx.hash().to_string(),
            case["rpc"]["txHash"].as_str().unwrap()
        );
    }
}

#[test]
fn vectors_public_keys_match_wallet_derivation() {
    let v = load("keys.json");
    let mnemonic = bip39::Mnemonic::parse(v["mnemonic"].as_str().unwrap()).unwrap();
    assert_eq!(
        hex::encode(mnemonic.to_seed("")),
        v["seed"].as_str().unwrap()
    );

    let mut tree = KeyTreePublic::new(&SeedHolder::from_mnemonic(&mnemonic, ""));
    // Entry 0 is the root; the rest follow the official wallet's layered order.
    for expected in &v["public"].as_array().unwrap()[1..] {
        let (id, path) = tree.generate_new_public_node_layered().unwrap();
        let node = tree.get_node(id).unwrap();
        assert_eq!(path.to_string(), expected["path"].as_str().unwrap());
        assert_eq!(
            id.to_string(),
            expected["accountId"]["base58"].as_str().unwrap()
        );
        assert_eq!(
            hex::encode(node.pk.value()),
            expected["pk"].as_str().unwrap()
        );
    }
}
