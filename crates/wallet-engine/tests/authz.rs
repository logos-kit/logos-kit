//! Integration-confidence test #3 (docs/dev/PLAN.md): the approval
//! authorization path. A dApp can't approve; Host/Unknown/Bridge fail closed;
//! no cross-caller status reads; approvals can't be replayed; a wrong echoed
//! hash cancels; the requester can cancel its own request; a restart drops
//! everything pending; and (on the standalone sequencer) a stale approval is
//! refused at sign time.

use wallet_engine::{
    engine::{Config, Engine, Lifecycle, RequestView, TxStatus},
    policy::{Caller, Capability, Code, code_of},
    session::{AccountKind, DataDir, Session, Zone},
    tx::Intent,
    vault::KdfCost,
};

const COST: KdfCost = KdfCost {
    m: 19 * 1024,
    t: 2,
    p: 1,
};
const PW: &str = "pw";
/// LEZ debug-genesis account (vendor/lez/Justfile `wallet-import-test-accounts`).
const GENESIS_KEY: &str = "7f273098f25b71e6c005a9519f2678da8d1c7f01f6a27778e2d9948abdf901fb";

fn dapp() -> Caller {
    Caller::Module("probe_dapp".into())
}

fn noop() -> impl FnMut(&TxStatus) + Send {
    |_| {}
}

fn engine_with_account(dir: &std::path::Path, zone: Zone) -> (Engine, String) {
    let (mut session, _) = Session::create(DataDir::new(dir), PW, zone, COST).unwrap();
    let account = session.new_account(AccountKind::Public).unwrap().account_id;
    (Engine::new(session, Config::default()), account)
}

fn hash_of(view: &RequestView) -> String {
    match view {
        RequestView::Connect { request_hash, .. } => request_hash.clone(),
        RequestView::Transaction(r) => r.request_hash.clone(),
    }
}

#[tokio::test]
async fn only_the_wallet_approves_and_only_once() {
    let dir = tempfile::tempdir().unwrap();
    let (engine, account) = engine_with_account(dir.path(), Zone::local());

    // Fail closed for callers we can't attribute.
    for caller in [Caller::Host, Caller::Bridge, Caller::Unknown] {
        let e = engine
            .request_connect(
                &caller,
                None,
                vec![account.clone()],
                vec![Capability::Accounts],
            )
            .await
            .unwrap_err();
        assert_eq!(code_of(&e), Code::Unauthorized, "{caller:?}");
    }

    // A dApp asks to connect (its own name, whatever it claims to relay).
    let ticket = engine
        .request_connect(
            &dapp(),
            Some("someone_else"),
            vec![account.clone()],
            vec![Capability::ProposeTx],
        )
        .await
        .unwrap();
    let RequestView::Connect { requester, .. } = &ticket.request else {
        panic!()
    };
    assert_eq!(requester, "probe_dapp");
    let hash = hash_of(&ticket.request);

    // One request at a time.
    let e = engine
        .request_connect(
            &dapp(),
            None,
            vec![account.clone()],
            vec![Capability::Accounts],
        )
        .await
        .unwrap_err();
    assert_eq!(code_of(&e), Code::RequestPending);

    // The dApp can't approve its own request, even with the right hash.
    let e = engine
        .approve(&dapp(), &ticket.handle, &hash, Some(PW), &mut noop())
        .await
        .unwrap_err();
    assert_eq!(code_of(&e), Code::Unauthorized);

    // Connect needs the password; a wrong one keeps the request open.
    let e = engine
        .approve(
            &Caller::WalletUi,
            &ticket.handle,
            &hash,
            Some("wrong"),
            &mut noop(),
        )
        .await
        .unwrap_err();
    assert_ne!(code_of(&e), Code::UnknownHandle);

    // The wallet approves once...
    engine
        .approve(
            &Caller::WalletUi,
            &ticket.handle,
            &hash,
            Some(PW),
            &mut noop(),
        )
        .await
        .unwrap();
    let granted = engine
        .with_session(async |s| Ok(s.grants().to_vec()))
        .await
        .unwrap();
    assert_eq!(granted.len(), 1);
    assert_eq!(granted[0].requester, "probe_dapp");

    // ...and never again (replay).
    let e = engine
        .approve(
            &Caller::WalletUi,
            &ticket.handle,
            &hash,
            Some(PW),
            &mut noop(),
        )
        .await
        .unwrap_err();
    assert_eq!(code_of(&e), Code::UnknownHandle);
}

#[tokio::test]
async fn a_wrong_echoed_hash_cancels_the_request() {
    let dir = tempfile::tempdir().unwrap();
    let (engine, account) = engine_with_account(dir.path(), Zone::local());
    let ticket = engine
        .request_connect(
            &dapp(),
            None,
            vec![account.clone()],
            vec![Capability::Accounts],
        )
        .await
        .unwrap();
    // An impersonating UI shown a different request echoes a different hash.
    let e = engine
        .approve(
            &Caller::WalletUi,
            &ticket.handle,
            &"00".repeat(32),
            Some(PW),
            &mut noop(),
        )
        .await
        .unwrap_err();
    assert_eq!(code_of(&e), Code::Unauthorized);
    // It was consumed: the real hash no longer works either.
    let e = engine
        .approve(
            &Caller::WalletUi,
            &ticket.handle,
            &hash_of(&ticket.request),
            Some(PW),
            &mut noop(),
        )
        .await
        .unwrap_err();
    assert_eq!(code_of(&e), Code::UnknownHandle);
}

#[tokio::test]
async fn requester_can_cancel_and_others_cannot() {
    let dir = tempfile::tempdir().unwrap();
    let (engine, account) = engine_with_account(dir.path(), Zone::local());
    let ticket = engine
        .request_connect(&dapp(), None, vec![account], vec![Capability::Accounts])
        .await
        .unwrap();
    let other = Caller::Module("other_dapp".into());
    assert_eq!(
        code_of(&engine.reject(&other, &ticket.handle).unwrap_err()),
        Code::UnknownHandle
    );
    engine.reject(&dapp(), &ticket.handle).unwrap();
    // Gone: a new request can be made.
    assert!(engine.reject(&Caller::WalletUi, &ticket.handle).is_err());
}

#[tokio::test]
async fn a_restart_drops_pending_requests() {
    let dir = tempfile::tempdir().unwrap();
    let (engine, account) = engine_with_account(dir.path(), Zone::local());
    let ticket = engine
        .request_connect(&dapp(), None, vec![account], vec![Capability::Accounts])
        .await
        .unwrap();
    engine.lock().await.unwrap();
    drop(engine);
    // Module restart: a fresh engine knows nothing about the old handle.
    let session = Session::unlock(DataDir::new(dir.path()), PW, Zone::local()).unwrap();
    let engine = Engine::new(session, Config::default());
    let e = engine
        .approve(
            &Caller::WalletUi,
            &ticket.handle,
            &hash_of(&ticket.request),
            Some(PW),
            &mut noop(),
        )
        .await
        .unwrap_err();
    assert_eq!(code_of(&e), Code::UnknownHandle);
}

#[tokio::test]
async fn a_dapp_without_a_grant_cannot_propose() {
    let dir = tempfile::tempdir().unwrap();
    let (engine, account) = engine_with_account(dir.path(), Zone::local());
    let e = engine
        .request_tx(
            &dapp(),
            None,
            Intent::Transfer {
                from: account.clone(),
                to: account,
                amount: 1,
            },
        )
        .await
        .unwrap_err();
    assert_eq!(code_of(&e), Code::Unauthorized);
}

/// Needs the standalone sequencer (`LK_E2E_SEQUENCER`).
#[tokio::test]
async fn e2e_status_is_private_and_stale_approvals_are_refused() {
    let Ok(url) = std::env::var("LK_E2E_SEQUENCER") else {
        eprintln!("skipped: set LK_E2E_SEQUENCER (see e2e/standalone.sh)");
        return;
    };
    let zone = Zone {
        id: "lez-local".into(),
        chain: "lez:local".into(),
        sequencer: url,
    };
    // Two wallets holding the same funded key: B moves the nonce under A.
    let (a_dir, b_dir) = (tempfile::tempdir().unwrap(), tempfile::tempdir().unwrap());
    let open = |dir: &std::path::Path| {
        let (mut s, _) = Session::create(DataDir::new(dir), PW, zone.clone(), COST).unwrap();
        let from = s.import_public_key(GENESIS_KEY).unwrap().account_id;
        let to = s.new_account(AccountKind::Public).unwrap().account_id;
        (Engine::new(s, Config::default()), from, to)
    };
    let (a, from, to_a) = open(a_dir.path());
    let (b, _, to_b) = open(b_dir.path());
    let owner = Caller::LocalOwner;
    let send = |to: &str| Intent::Transfer {
        from: from.clone(),
        to: to.to_owned(),
        amount: 7,
    };

    let ticket_a = a.request_tx(&owner, None, send(&to_a)).await.unwrap();
    // Status: the owner reads it; an unrelated dApp sees an unknown handle.
    assert_eq!(
        a.status(&owner, &ticket_a.handle).unwrap().lifecycle,
        Lifecycle::AwaitingApproval
    );
    assert_eq!(
        code_of(&a.status(&dapp(), &ticket_a.handle).unwrap_err()),
        Code::UnknownHandle
    );

    let ticket_b = b.request_tx(&owner, None, send(&to_b)).await.unwrap();
    let done = b
        .approve(
            &owner,
            &ticket_b.handle,
            &hash_of(&ticket_b.request),
            Some(PW),
            &mut noop(),
        )
        .await
        .unwrap();
    assert_eq!(done.lifecycle, Lifecycle::Included);

    // A's approval was made against the old nonce: refused at sign time.
    let e = a
        .approve(
            &owner,
            &ticket_a.handle,
            &hash_of(&ticket_a.request),
            Some(PW),
            &mut noop(),
        )
        .await
        .unwrap_err();
    assert_eq!(code_of(&e), Code::StaleApproval, "{e:#}");
    assert_eq!(
        a.status(&owner, &ticket_a.handle).unwrap().lifecycle,
        Lifecycle::Dropped
    );
}
