//! E2E (S2 exit): create accounts and sync against a real LEZ 0.3 sequencer.
//! Runs only when `LK_E2E_SEQUENCER` is set, e.g.
//!   e2e/standalone.sh && LK_E2E_SEQUENCER=http://127.0.0.1:3040 cargo test -p wallet-engine --test e2e_sync

use std::sync::{Arc, Mutex};

use wallet::sync_observer::SyncObserver;
use wallet_engine::{
    session::{AccountKind, BIRTHDAY_MARGIN_MS, Birthday, DataDir, Session, Zone},
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

#[tokio::test]
async fn e2e_restore_skips_blocks_before_birthday_and_discovers() {
    let Ok(url) = std::env::var("LK_E2E_SEQUENCER") else {
        eprintln!("skipped: set LK_E2E_SEQUENCER (see e2e/standalone.sh)");
        return;
    };
    let zone = Zone {
        id: "lez-local".into(),
        chain: "lez:local".into(),
        sequencer: url,
    };
    let a = tempfile::tempdir().unwrap();
    let (mut original, phrase) =
        Session::create(DataDir::new(a.path()), "pw", zone.clone(), COST).unwrap();
    original.connect().await.expect("connect");
    let core = original.core().unwrap();
    // A fresh sequencer may have only genesis: wait for a few blocks (a
    // cached build no longer gives it that time).
    let mut tip = core.get_last_block_id().await.unwrap();
    for _ in 0..120 {
        if tip >= 4 {
            break;
        }
        tokio::time::sleep(std::time::Duration::from_secs(1)).await;
        tip = core.get_last_block_id().await.unwrap();
    }
    assert!(
        tip >= 4,
        "the sequencer made no blocks in 2 min (tip {tip})"
    );
    let mid = tip / 2;
    let mid_ts = core.get_block(mid).await.unwrap().unwrap().header.timestamp;
    original.lock().unwrap();

    // Restore date = the mid block's time: scanning starts there, not at 1.
    let b = tempfile::tempdir().unwrap();
    let mut restored = Session::restore(
        DataDir::new(b.path()),
        "pw",
        &phrase,
        Birthday::At(mid_ts + BIRTHDAY_MARGIN_MS),
        zone,
        COST,
    )
    .unwrap();
    let tree = restored.accounts().unwrap().len();
    assert!(restored.status().unwrap().discovering);
    let mut recorder = Recorder::default();
    restored.sync(&mut recorder).await.expect("sync");
    let events = recorder.0.lock().unwrap().clone();
    eprintln!("mid {mid} (ts {mid_ts}); observer saw {events:?}");
    let start: u64 = events[0]
        .strip_prefix("start ")
        .and_then(|r| r.split("..=").next())
        .and_then(|n| n.parse().ok())
        .expect("a start event");
    assert!(
        start > 1 && start <= mid,
        "scan began at {start}, mid is {mid}"
    );

    // Discovery ran: nothing was used on chain, so the tree shrinks back.
    let status = restored.status().unwrap();
    assert!(!status.discovering);
    let left = restored.accounts().unwrap().len();
    eprintln!("discovery tree {tree} accounts → {left} after cleanup");
    assert!(left < tree);
}
