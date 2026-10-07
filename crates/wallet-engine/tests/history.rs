//! Activity history (stage W): finished rows survive a restart, stay with the
//! zone they happened on even when two zones share a chain id, and an app
//! still reads only its own restored rows.

use wallet_engine::{
    engine::{Config, Engine, Lifecycle},
    policy::{Caller, Capability},
    session::{AccountKind, DataDir, Session, Zone},
    vault::KdfCost,
};

const COST: KdfCost = KdfCost {
    m: 19 * 1024,
    t: 2,
    p: 1,
};
const PW: &str = "pw-history";

fn dapp() -> Caller {
    Caller::Module("probe_dapp".into())
}

/// A second zone on the same chain id as `Zone::local()`.
fn twin() -> Zone {
    Zone {
        id: "lez-local-twin".into(),
        chain: "lez:local".into(),
        sequencer: "http://127.0.0.1:3041".into(),
    }
}

/// An app's connect request, declined: a finished row with a requester.
async fn declined_row(engine: &Engine, account: &str) -> String {
    let ticket = engine
        .request_connect(
            &dapp(),
            None,
            vec![account.to_owned()],
            vec![Capability::Accounts],
        )
        .await
        .unwrap();
    engine.reject(&Caller::WalletUi, &ticket.handle).unwrap();
    ticket.handle
}

#[tokio::test]
async fn history_survives_a_restart_and_stays_with_its_zone() {
    let dir = tempfile::tempdir().unwrap();
    let data = || DataDir::new(dir.path());
    let (mut session, _) = Session::create(data(), PW, Zone::local(), COST).unwrap();
    let account = session.new_account(AccountKind::Public).unwrap().account_id;
    let engine = Engine::new(session, Config::default());
    let handle = declined_row(&engine, &account).await;
    engine.lock().await.unwrap();
    drop(engine);

    // Restart on the same zone: the declined request is still in the activity,
    // and the app that made it can still read it; another app can't.
    let engine = Engine::new(
        Session::unlock(data(), PW, Zone::local()).unwrap(),
        Config::default(),
    );
    let mine = engine.statuses(&Caller::WalletUi);
    let row = mine
        .iter()
        .find(|s| s.handle == handle)
        .expect("row restored");
    assert_eq!(row.lifecycle, Lifecycle::Rejected);
    assert!(
        engine.status(&dapp(), &handle).is_ok(),
        "the requester reads its own row"
    );
    let other = Caller::Module("someone_else".into());
    assert!(engine.status(&other, &handle).is_err(), "another app can't");

    // Another zone with the same chain id (switched the way the service does:
    // lock, then unlock there): its own, empty history.
    engine.lock().await.unwrap();
    engine
        .set_session(Session::unlock(data(), PW, twin()).unwrap())
        .await
        .unwrap();
    assert!(
        engine
            .statuses(&Caller::WalletUi)
            .iter()
            .all(|s| s.handle != handle),
        "a row from lez-local showed on lez-local-twin"
    );
    let twin_handle = declined_row(&engine, &account).await;
    engine.flush_history().await.unwrap();

    // Back on the first zone: its row is back, the twin's isn't.
    engine.lock().await.unwrap();
    engine
        .set_session(Session::unlock(data(), PW, Zone::local()).unwrap())
        .await
        .unwrap();
    let rows = engine.statuses(&Caller::WalletUi);
    assert!(rows.iter().any(|s| s.handle == handle));
    assert!(rows.iter().all(|s| s.handle != twin_handle));
    engine.lock().await.unwrap();
}
