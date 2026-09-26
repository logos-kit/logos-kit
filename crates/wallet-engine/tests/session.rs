//! Session lifecycle against real LEZ storage: create, persist, lock, unlock,
//! restore the same phrase elsewhere, zones, the key hierarchy, and staying
//! usable offline (part of integration-confidence #2; the sync half runs in
//! the standalone E2E).

use std::time::Duration;

use wallet_engine::{
    session::{AccountKind, Birthday, DataDir, NetStatus, Offline, Session, Throttled, Zone},
    vault::KdfCost,
};

const COST: KdfCost = KdfCost {
    m: 19 * 1024,
    t: 2,
    p: 1,
};

fn other_zone() -> Zone {
    Zone {
        id: "lez-other".into(),
        chain: "lez:other".into(),
        sequencer: "http://127.0.0.1:3041".into(),
    }
}

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

    // The same phrase elsewhere derives the same account (inside the
    // discovery tree, until the first sync prunes unused ones).
    let b = tempfile::tempdir().unwrap();
    let restored = Session::restore(
        DataDir::new(b.path()),
        "other",
        &phrase,
        Birthday::Genesis,
        Zone::local(),
        COST,
    )
    .unwrap();
    assert!(restored.status().unwrap().discovering);
    assert!(
        restored
            .accounts()
            .unwrap()
            .iter()
            .any(|x| x.account_id == added.account_id)
    );
}

#[test]
fn zones_share_accounts_and_labels_under_one_password() {
    let dir = tempfile::tempdir().unwrap();
    let data = || DataDir::new(dir.path());
    let (mut session, _) = Session::create(data(), "pw", Zone::local(), COST).unwrap();
    let savings = session.new_account(AccountKind::Public).unwrap();
    let hidden = session.new_account(AccountKind::Private).unwrap();
    session
        .set_label(&savings.account_id, Some("Savings"))
        .unwrap();
    session
        .set_label(&hidden.account_id, Some("Hidden"))
        .unwrap();
    assert!(
        session
            .set_label(&hidden.account_id, Some("Savings"))
            .is_err(),
        "labels are unique"
    );
    session
        .set_label(&savings.account_id, Some(" Rainy day "))
        .unwrap();
    session.lock().unwrap();

    // A second zone gets the same accounts and labels, derived offline.
    let other = Session::unlock(data(), "pw", other_zone()).unwrap();
    let accounts = other.accounts().unwrap();
    let find = |id: &str| accounts.iter().find(|a| a.account_id == id).cloned();
    assert_eq!(
        find(&savings.account_id).unwrap().label.as_deref(),
        Some("Rainy day")
    );
    assert_eq!(
        find(&hidden.account_id).unwrap().label.as_deref(),
        Some("Hidden")
    );
    let mut other = other;

    // Password change rewrites the keys vault only; every zone follows.
    other.change_password("pw", "new pw").unwrap();
    other.lock().unwrap();
    assert!(Session::unlock(data(), "pw", Zone::local()).is_err());
    let local = Session::unlock(data(), "new pw", Zone::local()).unwrap();
    assert_eq!(
        local
            .accounts()
            .unwrap()
            .iter()
            .find(|a| a.account_id == savings.account_id)
            .unwrap()
            .label
            .as_deref(),
        Some("Rainy day")
    );

    // One process at a time.
    assert!(Session::unlock(data(), "new pw", other_zone()).is_err());
    local.lock().unwrap();

    // A zone keeps the URL it was added with; a changed one is refused.
    let mut moved = other_zone();
    moved.sequencer = "http://evil.example:3040".into();
    assert!(Session::unlock(data(), "new pw", moved).is_err());
}

#[test]
fn a_zone_vault_swapped_into_another_zone_is_rejected() {
    let dir = tempfile::tempdir().unwrap();
    let data = || DataDir::new(dir.path());
    let (session, _) = Session::create(data(), "pw", Zone::local(), COST).unwrap();
    session.lock().unwrap();
    Session::unlock(data(), "pw", other_zone())
        .unwrap()
        .lock()
        .unwrap();
    std::fs::copy(
        dir.path().join("zones/lez-local/vault.json"),
        dir.path().join("zones/lez-other/vault.json"),
    )
    .unwrap();
    let err = Session::unlock(data(), "pw", other_zone())
        .err()
        .expect("swapped vault must not open");
    assert!(format!("{err:#}").contains("does not belong"), "{err:#}");
}

#[test]
fn phrase_reveal_needs_the_password_and_is_throttled() {
    let dir = tempfile::tempdir().unwrap();
    let (mut session, phrase) =
        Session::create(DataDir::new(dir.path()), "pw", Zone::local(), COST).unwrap();
    assert_eq!(*session.reveal_phrase("pw").unwrap(), *phrase);
    for _ in 0..3 {
        assert!(session.reveal_phrase("nope").is_err());
    }
    // Now even the right password waits.
    let err = session.reveal_phrase("pw").unwrap_err();
    assert!(err.downcast_ref::<Throttled>().is_some(), "{err:#}");
    std::thread::sleep(Duration::from_millis(1100));
    assert_eq!(*session.reveal_phrase("pw").unwrap(), *phrase);
}

#[tokio::test]
async fn network_drop_goes_offline_with_backoff() {
    let a = tempfile::tempdir().unwrap();
    // Nothing listens on the discard port.
    let zone = Zone {
        id: "nowhere".into(),
        chain: "lez:nowhere".into(),
        sequencer: "http://127.0.0.1:9".into(),
    };
    let (mut session, _) = Session::create(DataDir::new(a.path()), "pw", zone, COST).unwrap();
    assert_eq!(session.status().unwrap().network, NetStatus::Idle);
    assert!(session.connect().await.is_err());
    assert!(!session.is_online());
    // Still usable offline after the failed connect.
    session.new_account(AccountKind::Private).unwrap();
    assert!(!session.accounts().unwrap().is_empty());

    let mut quiet = wallet_engine_noop();
    let first = session.sync(&mut quiet).await.unwrap_err();
    assert!(first.downcast_ref::<Offline>().is_none(), "a real attempt");
    let NetStatus::Offline { attempts: 1, .. } = session.status().unwrap().network else {
        panic!("expected offline after one attempt");
    };
    // Inside the backoff window: fail fast, no network attempt.
    let second = session.sync(&mut quiet).await.unwrap_err();
    assert!(second.downcast_ref::<Offline>().is_some(), "{second:#}");
    // "Retry" tries again right away and counts the attempt.
    session.retry_now();
    assert!(session.sync(&mut quiet).await.is_err());
    let NetStatus::Offline { attempts: 2, .. } = session.status().unwrap().network else {
        panic!("expected a second attempt");
    };
}

fn wallet_engine_noop() -> impl wallet::sync_observer::SyncObserver {
    struct Noop;
    impl wallet::sync_observer::SyncObserver for Noop {}
    Noop
}
