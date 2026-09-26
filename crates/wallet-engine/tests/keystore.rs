//! Integration-confidence test #2 (docs/dev/PLAN.md): the encrypted keystore
//! survives the failures that lose wallets: wrong password, tampering, a crash
//! mid-write, password change, and LEZ's save-every-block cadence.

use std::{fs, time::Duration};

use wallet::storage::StorageBackend as _;
use wallet_engine::vault::{EncryptedBackend, KdfCost, Vault};

// The floor cost: realistic Argon2id, fast enough for a test.
const COST: KdfCost = KdfCost {
    m: 19 * 1024,
    t: 2,
    p: 1,
};

fn vault_json(dir: &std::path::Path) -> serde_json::Value {
    serde_json::from_slice(&fs::read(dir.join("vault.json")).unwrap()).unwrap()
}

#[test]
fn keystore_round_trip_and_wrong_password() {
    let dir = tempfile::tempdir().unwrap();
    Vault::create(dir.path(), "correct horse", b"wallet-state-v1", COST).unwrap();

    let (_, plain) = Vault::unlock(dir.path(), "correct horse").unwrap();
    assert_eq!(plain.as_slice(), b"wallet-state-v1");
    assert!(Vault::unlock(dir.path(), "wrong").is_err());
    assert!(
        Vault::create(dir.path(), "x", b"y", COST).is_err(),
        "must not overwrite an existing vault"
    );

    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt as _;
        let mode = fs::metadata(dir.path().join("vault.json"))
            .unwrap()
            .permissions()
            .mode();
        assert_eq!(mode & 0o777, 0o600);
    }
}

#[test]
fn keystore_header_is_authenticated_and_bounded() {
    let dir = tempfile::tempdir().unwrap();
    Vault::create(dir.path(), "pw", b"secret", COST).unwrap();
    let original = fs::read(dir.path().join("vault.json")).unwrap();

    // In-bounds but different parameters: the AEAD tag must fail.
    let mut v = vault_json(dir.path());
    v["kdf"]["t"] = 3.into();
    fs::write(
        dir.path().join("vault.json"),
        serde_json::to_vec(&v).unwrap(),
    )
    .unwrap();
    assert!(Vault::unlock(dir.path(), "pw").is_err());

    // Out-of-bounds cost is refused before any KDF runs (no 4 GiB allocation).
    v["kdf"]["t"] = 2.into();
    v["kdf"]["m"] = (4_u64 * 1024 * 1024).into();
    fs::write(
        dir.path().join("vault.json"),
        serde_json::to_vec(&v).unwrap(),
    )
    .unwrap();
    let err = Vault::unlock(dir.path(), "pw").err().unwrap().to_string();
    assert!(err.contains("out of bounds"), "{err}");

    fs::write(dir.path().join("vault.json"), original).unwrap();
    assert!(Vault::unlock(dir.path(), "pw").is_ok());
}

#[test]
fn keystore_survives_crash_mid_write() {
    let dir = tempfile::tempdir().unwrap();
    let vault = Vault::create(dir.path(), "pw", b"state-1", COST).unwrap();
    // A crash after writing the staged file but before the rename.
    fs::write(dir.path().join(".vault.json.staged"), b"{ torn").unwrap();
    assert_eq!(
        Vault::unlock(dir.path(), "pw").unwrap().1.as_slice(),
        b"state-1"
    );
    // The next save replaces the leftover and commits normally.
    vault.save(b"state-2").unwrap();
    assert_eq!(
        Vault::unlock(dir.path(), "pw").unwrap().1.as_slice(),
        b"state-2"
    );
}

#[test]
fn keystore_change_password() {
    let dir = tempfile::tempdir().unwrap();
    let mut vault = Vault::create(dir.path(), "old", b"state", COST).unwrap();
    assert!(vault.change_password("not-old", "new", b"state").is_err());
    vault.change_password("old", "new", b"state").unwrap();
    assert!(Vault::unlock(dir.path(), "old").is_err());
    assert_eq!(
        Vault::unlock(dir.path(), "new").unwrap().1.as_slice(),
        b"state"
    );
}

#[test]
fn keystore_backend_debounces_block_saves() {
    let dir = tempfile::tempdir().unwrap();
    let vault = Vault::create(dir.path(), "pw", b"block-0", COST).unwrap();
    let backend = EncryptedBackend::new(vault, Duration::from_secs(3600));

    backend.save(b"block-1").unwrap(); // first save writes
    backend.save(b"block-2").unwrap(); // within the interval: buffered
    assert_eq!(
        Vault::unlock(dir.path(), "pw").unwrap().1.as_slice(),
        b"block-1"
    );
    assert_eq!(
        backend.load().unwrap().as_deref(),
        Some(&b"block-2"[..]),
        "load sees the newest bytes"
    );

    backend.flush().unwrap();
    assert_eq!(
        Vault::unlock(dir.path(), "pw").unwrap().1.as_slice(),
        b"block-2"
    );
    assert_eq!(
        backend.load().unwrap().as_deref(),
        Some(&b"block-2"[..]),
        "reads back from disk after flush"
    );
}
