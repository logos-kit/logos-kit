//! Integration-confidence test #1 (docs/dev/PLAN.md): the committed
//! `protocol/vectors/*.json` still agree with LEZ at the pinned rev.
//!
//! `cargo xtask vectors` *encodes* with LEZ; this test *decodes* the committed
//! bytes with LEZ and re-verifies them, so a LEZ re-pin that changes the wire
//! format or key derivation fails here until the vectors are regenerated.

use std::{fs, path::PathBuf};

use base64::{Engine as _, engine::general_purpose::STANDARD as B64};
use common::transaction::LeeTransaction;
use key_protocol::key_management::{
    key_tree::{KeyTreePrivate, KeyTreePublic, keys_public::ChildKeysPublic, traits::KeyTreeNode},
    secret_holders::SeedHolder,
};
use lee::{PublicKey, PublicTransaction, Signature, public_transaction::Message};
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
fn vectors_rev_matches_engine_and_vendored_lez() {
    let tree = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../vendor/lez");
    let based = std::process::Command::new("git")
        .arg("-C")
        .arg(&tree)
        .args([
            "merge-base",
            "--is-ancestor",
            wallet_engine::LEZ_REV,
            "HEAD",
        ])
        .status()
        .expect("git in vendor/lez");
    assert!(
        based.success(),
        "vendor/lez is not based on wallet_engine::LEZ_REV"
    );
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

        let msg: Message = borsh::from_slice(&hex_field(case, "borsh")).unwrap();
        let sig: Signature = case["signature"].as_str().unwrap().parse().unwrap();
        let pk: PublicKey = case["publicKey"].as_str().unwrap().parse().unwrap();
        assert!(
            sig.is_valid_for(&msg.hash(), &pk),
            "listed signature must verify"
        );

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
fn vectors_keys_match_wallet_derivation() {
    let v = load("keys.json");
    let mnemonic = bip39::Mnemonic::parse(v["mnemonic"].as_str().unwrap()).unwrap();
    assert_eq!(
        hex::encode(mnemonic.to_seed("")),
        v["seed"].as_str().unwrap()
    );

    let seed = SeedHolder::from_mnemonic(&mnemonic, "");
    let check = |expected: &Value, node: &ChildKeysPublic| {
        assert_eq!(
            hex::encode(node.sk.value()),
            expected["sk"].as_str().unwrap(),
            "{}",
            expected["path"]
        );
        assert_eq!(
            hex::encode(node.ssk.value()),
            expected["ssk"].as_str().unwrap(),
            "{}",
            expected["path"]
        );
        assert_eq!(
            hex::encode(node.pk.value()),
            expected["pk"].as_str().unwrap(),
            "{}",
            expected["path"]
        );
        assert_eq!(
            hex::encode(node.cc),
            expected["cc"].as_str().unwrap(),
            "{}",
            expected["path"]
        );
        assert_eq!(
            node.account_id().to_string(),
            expected["accountId"]["base58"].as_str().unwrap()
        );
    };

    let public = v["public"].as_array().unwrap();
    check(&public[0], &ChildKeysPublic::root(mnemonic.to_seed("")));
    let mut tree = KeyTreePublic::new(&seed);
    // The rest follow the official wallet's layered order.
    for expected in &public[1..] {
        let (id, path) = tree.generate_new_public_node_layered().unwrap();
        assert_eq!(path.to_string(), expected["path"].as_str().unwrap());
        check(expected, tree.get_node(id).unwrap());
    }

    let mut private = KeyTreePrivate::new(&seed);
    for expected in v["private"].as_array().unwrap() {
        let path = private.create_private_accounts_key_node_layered().unwrap();
        assert_eq!(path.to_string(), expected["path"].as_str().unwrap());
        let node = private.key_map.get(&path).unwrap();
        let ids: Vec<String> = node.account_ids().map(|id| id.to_string()).collect();
        let want: Vec<String> = expected["accountIds"]
            .as_array()
            .unwrap()
            .iter()
            .map(|a| a["base58"].as_str().unwrap().to_owned())
            .collect();
        assert_eq!(ids, want, "private {}", expected["path"]);
        assert_eq!(hex::encode(node.ccc), expected["ccc"].as_str().unwrap());
    }
}
