//! E2E (S2 exit): create accounts and sync against a real LEZ 0.3 sequencer.
//! Runs only when `LK_E2E_SEQUENCER` is set, e.g.
//!   e2e/standalone.sh && LK_E2E_SEQUENCER=http://127.0.0.1:3040 cargo test -p wallet-engine --test e2e_sync

use std::sync::{Arc, Mutex};

use wallet::sync_observer::SyncObserver;
use wallet_engine::{
    session::{AccountKind, DataDir, Session, Zone},
    vault::KdfCost,
};

const COST: KdfCost = KdfCost {
    m: 19 * 1024,
    t: 2,
    p: 1,
};

/// Records what LEZ reports while syncing (what the UI will show).
#[derive(Default, Clone)]
struct Recorder(Arc<Mutex<Vec<String>>>);

impl SyncObserver for Recorder {
    fn on_start(&mut self, blocks: std::ops::RangeInclusive<u64>) {
        self.0.lock().unwrap().push(format!("start {blocks:?}"));
    }
    fn on_finish(&mut self, block_id: u64, _: std::time::Duration) {
        self.0.lock().unwrap().push(format!("finish {block_id}"));
    }
}

#[tokio::test]
async fn e2e_create_accounts_and_sync() {
    let Ok(url) = std::env::var("LK_E2E_SEQUENCER") else {
        eprintln!("skipped: set LK_E2E_SEQUENCER (see e2e/standalone.sh)");
        return;
    };
    let zone = Zone {
        id: "lez-local".into(),
        chain: "lez:local".into(),
        sequencer: url,
    };
    let dir = tempfile::tempdir().unwrap();
    let (mut session, _) =
        Session::create(DataDir::new(dir.path()), "pw", zone.clone(), COST).unwrap();
    session.new_account(AccountKind::Public).unwrap();
    session.new_account(AccountKind::Private).unwrap();

    session
        .connect()
        .await
        .expect("connect to the standalone sequencer");
    assert!(session.is_online());
    let mut recorder = Recorder::default();
    let tip = session.sync(&mut recorder).await.expect("sync");
    let events = recorder.0.lock().unwrap().clone();
    eprintln!("synced to block {tip}; observer saw {events:?}");
    assert!(tip >= 1, "the sequencer has produced at least genesis");

    // Sync position is part of the encrypted storage and survives lock/unlock.
    session.lock().unwrap();
    let mut again = Session::unlock(DataDir::new(dir.path()), "pw", zone).unwrap();
    let tip2 = again.sync(&mut Recorder::default()).await.unwrap();
    assert!(tip2 >= tip);
}
