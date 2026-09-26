//! Session lifecycle against real LEZ storage: create, persist, lock, unlock,
//! restore the same phrase elsewhere, and stay usable offline (part of
//! integration-confidence #2; the sync half runs in the standalone E2E).

use wallet_engine::{
    session::{AccountKind, DataDir, Session, Zone},
    vault::KdfCost,
};

const COST: KdfCost = KdfCost {
    m: 19 * 1024,
    t: 2,
    p: 1,
};

#[test]
fn session_create_lock_unlock_restore_offline() {
    let a = tempfile::tempdir().unwrap();
    let (mut session, phrase) =
        Session::create(DataDir::new(a.path()), "pw", Zone::local(), COST).unwrap();
    assert!(
        !session.is_online(),
        "no sequencer is needed to create a wallet"
    );
    let before = session.accounts().unwrap();
    let added = session.new_account(AccountKind::Public).unwrap();
    session.lock().unwrap();

    // Nothing readable at rest: the zone vault holds ciphertext only.
    let raw = std::fs::read_to_string(a.path().join("zones/lez-local/vault.json")).unwrap();
    assert!(raw.contains("logos-kit.vault.v1") && !raw.contains(&added.account_id));

    assert!(Session::unlock(DataDir::new(a.path()), "wrong", Zone::local()).is_err());
    let session = Session::unlock(DataDir::new(a.path()), "pw", Zone::local()).unwrap();
    let after = session.accounts().unwrap();
    assert!(
        after.contains(&added),
        "a derived account survives lock/unlock"
    );
    assert_eq!(after.len(), before.len() + 1);

    // The same phrase elsewhere derives the same public accounts in the same order.
    let b = tempfile::tempdir().unwrap();
    let mut restored = Session::restore(
        DataDir::new(b.path()),
        "other",
        &phrase,
        Zone::local(),
        COST,
    )
    .unwrap();
    let again = restored.new_account(AccountKind::Public).unwrap();
    assert_eq!(again.account_id, added.account_id);
}

#[tokio::test]
async fn session_connect_failure_stays_offline() {
    let a = tempfile::tempdir().unwrap();
    // Nothing listens on the discard port.
    let zone = Zone {
        id: "nowhere".into(),
        chain: "lez:nowhere".into(),
        sequencer: "http://127.0.0.1:9".into(),
    };
    let (mut session, _) = Session::create(DataDir::new(a.path()), "pw", zone, COST).unwrap();
    assert!(session.connect().await.is_err());
    assert!(!session.is_online());
    // Still usable offline after the failed connect.
    session.new_account(AccountKind::Private).unwrap();
    assert!(!session.accounts().unwrap().is_empty());
}
