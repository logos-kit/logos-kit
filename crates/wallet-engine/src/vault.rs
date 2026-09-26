//! `vault.v1`: the encrypted-at-rest wallet file.
//!
//! - Key: Argon2id(password, salt), derived once at unlock and kept in
//!   [`Zeroizing`] memory for the session.
//! - Seal: XChaCha20-Poly1305, fresh random 24-byte nonce per write. The
//!   header (format, KDF parameters, salt, cipher) is the AEAD associated
//!   data, so nobody can swap in weaker parameters without breaking the tag.
//! - Load: KDF parameters are bounded on both sides: a floor so a tampered
//!   file can't downgrade the work factor, a ceiling so it can't make unlock
//!   allocate gigabytes.
//! - Write: lock file, staged file (0600) in the same directory, fsync,
//!   rename over the old file, fsync the directory. A crash leaves either the
//!   old vault or the new one, never a torn file. Pattern follows
//!   logos-accounts-ui `rust-core/src/vault.rs` (MIT OR Apache-2.0).
//!
//! [`EncryptedBackend`] plugs this into LEZ's `StorageBackend` (our patch
//! 0001), debouncing the wallet's save-per-synced-block cadence.

use std::{
    fs::{self, File, OpenOptions},
    io::Write as _,
    path::{Path, PathBuf},
    sync::Mutex,
    time::{Duration, Instant},
};

use anyhow::{Context as _, Result, bail, ensure};
use argon2::{Algorithm, Argon2, Params, Version};
use base64::{Engine as _, engine::general_purpose::STANDARD as B64};
use chacha20poly1305::{
    XChaCha20Poly1305, XNonce,
    aead::{Aead, AeadCore, KeyInit, OsRng, Payload, rand_core::RngCore as _},
};
use serde::{Deserialize, Serialize};
use zeroize::Zeroizing;

pub const FORMAT: &str = "logos-kit.vault.v1";
const CIPHER: &str = "xchacha20poly1305";
const VAULT_FILE: &str = "vault.json";
const STAGED_FILE: &str = ".vault.json.staged";
const LOCK_FILE: &str = ".vault.lock";
const LOCK_WAIT: Duration = Duration::from_secs(2);

/// Argon2id cost. Defaults: 64 MiB, 3 passes, 1 lane (RFC 9106 §4, second
/// recommendation, single lane so phones and laptops derive in ~0.5 s).
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct KdfCost {
    /// Memory in KiB.
    pub m: u32,
    pub t: u32,
    pub p: u32,
}

impl KdfCost {
    pub const DEFAULT: Self = Self {
        m: 64 * 1024,
        t: 3,
        p: 1,
    };
    /// Floor: OWASP's Argon2id minimum (19 MiB, t=2). Anything weaker is a downgrade.
    const MIN: Self = Self {
        m: 19 * 1024,
        t: 2,
        p: 1,
    };
    /// Ceiling: refuse files that would allocate over 1 GiB or spin for ages.
    const MAX: Self = Self {
        m: 1024 * 1024,
        t: 10,
        p: 8,
    };

    fn check(self) -> Result<Self> {
        ensure!(
            (Self::MIN.m..=Self::MAX.m).contains(&self.m)
                && (Self::MIN.t..=Self::MAX.t).contains(&self.t)
                && (Self::MIN.p..=Self::MAX.p).contains(&self.p),
            "vault KDF parameters out of bounds: {self:?}"
        );
        Ok(self)
    }
}

#[derive(Serialize, Deserialize)]
struct Kdf {
    alg: String,
    #[serde(flatten)]
    cost: KdfCost,
    salt: String,
}

#[derive(Serialize, Deserialize)]
struct VaultFile {
    format: String,
    kdf: Kdf,
    cipher: String,
    nonce: String,
    ciphertext: String,
}

/// The associated data: a fixed-order rendering of everything but the nonce
/// and ciphertext (so it doesn't depend on a JSON serializer's key order).
fn aad(cost: KdfCost, salt: &[u8]) -> Vec<u8> {
    format!(
        "{FORMAT}|argon2id|m={}|t={}|p={}|salt={}|{CIPHER}",
        cost.m,
        cost.t,
        cost.p,
        B64.encode(salt)
    )
    .into_bytes()
}

fn derive(password: &str, salt: &[u8], cost: KdfCost) -> Result<Zeroizing<[u8; 32]>> {
    let params = Params::new(cost.m, cost.t, cost.p, Some(32))
        .map_err(|e| anyhow::anyhow!("argon2 params: {e}"))?;
    let mut key = Zeroizing::new([0_u8; 32]);
    Argon2::new(Algorithm::Argon2id, Version::V0x13, params)
        .hash_password_into(password.as_bytes(), salt, key.as_mut())
        .map_err(|e| anyhow::anyhow!("argon2: {e}"))?;
    Ok(key)
}

/// Held while reading or writing the vault, so the CLI and the Basecamp
/// module (same data dir) never interleave writes. Released on drop.
struct DirLock(File);

impl DirLock {
    fn acquire(dir: &Path) -> Result<Self> {
        let file = OpenOptions::new()
            .create(true)
            .truncate(false)
            .write(true)
            .open(dir.join(LOCK_FILE))?;
        let start = Instant::now();
        loop {
            match file.try_lock() {
                Ok(()) => return Ok(Self(file)),
                Err(fs::TryLockError::WouldBlock) if start.elapsed() < LOCK_WAIT => {
                    std::thread::sleep(Duration::from_millis(25));
                }
                Err(fs::TryLockError::WouldBlock) => {
                    bail!("another Logos Kit process is writing the vault")
                }
                Err(fs::TryLockError::Error(e)) => return Err(e.into()),
            }
        }
    }
}

impl Drop for DirLock {
    fn drop(&mut self) {
        let _ = self.0.unlock();
    }
}

#[cfg(unix)]
fn private_file(path: &Path) -> Result<File> {
    use std::os::unix::fs::OpenOptionsExt as _;
    Ok(OpenOptions::new()
        .create(true)
        .truncate(true)
        .write(true)
        .mode(0o600)
        .open(path)?)
}

#[cfg(not(unix))]
fn private_file(path: &Path) -> Result<File> {
    Ok(OpenOptions::new()
        .create(true)
        .truncate(true)
        .write(true)
        .open(path)?)
}

/// Replace `dest` atomically with `bytes` (staged file + fsync + rename + dir fsync).
fn atomic_write(dir: &Path, bytes: &[u8]) -> Result<()> {
    let staged = dir.join(STAGED_FILE);
    {
        let mut f = private_file(&staged)?;
        f.write_all(bytes)?;
        f.sync_all()?;
    }
    fs::rename(&staged, dir.join(VAULT_FILE))?;
    // Without this the rename is atomic but may not survive power loss.
    #[cfg(unix)]
    File::open(dir)?.sync_all()?;
    Ok(())
}

/// An unlocked vault: the directory plus the derived key for this session.
pub struct Vault {
    dir: PathBuf,
    cost: KdfCost,
    salt: [u8; 16],
    key: Zeroizing<[u8; 32]>,
}

impl Vault {
    pub fn exists(dir: &Path) -> bool {
        dir.join(VAULT_FILE).is_file()
    }

    /// Create a new vault holding `plaintext`. Fails if one already exists.
    pub fn create(
        dir: impl Into<PathBuf>,
        password: &str,
        plaintext: &[u8],
        cost: KdfCost,
    ) -> Result<Self> {
        let dir = dir.into();
        fs::create_dir_all(&dir)?;
        let _lock = DirLock::acquire(&dir)?;
        ensure!(
            !Self::exists(&dir),
            "a vault already exists in {}",
            dir.display()
        );
        let mut salt = [0_u8; 16];
        OsRng.fill_bytes(&mut salt);
        let key = derive(password, &salt, cost.check()?)?;
        let vault = Self {
            dir,
            cost,
            salt,
            key,
        };
        vault.write_locked(plaintext)?;
        Ok(vault)
    }

    /// Unlock: derive the key from `password` and decrypt. A wrong password
    /// and a tampered file both fail the AEAD tag with the same error.
    pub fn unlock(dir: impl Into<PathBuf>, password: &str) -> Result<(Self, Zeroizing<Vec<u8>>)> {
        let dir = dir.into();
        let _lock = DirLock::acquire(&dir)?;
        let file: VaultFile =
            serde_json::from_slice(&fs::read(dir.join(VAULT_FILE)).context("read vault")?)
                .context("vault is not valid JSON")?;
        ensure!(
            file.format == FORMAT && file.cipher == CIPHER && file.kdf.alg == "argon2id",
            "unsupported vault format"
        );
        let cost = file.kdf.cost.check()?;
        let salt: [u8; 16] = B64
            .decode(&file.kdf.salt)?
            .try_into()
            .map_err(|_| anyhow::anyhow!("vault salt must be 16 bytes"))?;
        let nonce_bytes = B64.decode(&file.nonce)?;
        ensure!(nonce_bytes.len() == 24, "vault nonce must be 24 bytes");
        let key = derive(password, &salt, cost)?;
        let plaintext = XChaCha20Poly1305::new(key.as_ref().into())
            .decrypt(
                XNonce::from_slice(&nonce_bytes),
                Payload {
                    msg: &B64.decode(&file.ciphertext)?,
                    aad: &aad(cost, &salt),
                },
            )
            .map_err(|_| anyhow::anyhow!("wrong password or damaged vault"))?;
        Ok((
            Self {
                dir,
                cost,
                salt,
                key,
            },
            Zeroizing::new(plaintext),
        ))
    }

    /// Re-encrypt `plaintext` under the session key (new nonce every time).
    pub fn save(&self, plaintext: &[u8]) -> Result<()> {
        let _lock = DirLock::acquire(&self.dir)?;
        self.write_locked(plaintext)
    }

    /// New password: new salt, new key, same contents. `current` must match.
    pub fn change_password(&mut self, current: &str, new: &str, plaintext: &[u8]) -> Result<()> {
        ensure!(
            *derive(current, &self.salt, self.cost)? == *self.key,
            "current password is wrong"
        );
        let mut salt = [0_u8; 16];
        OsRng.fill_bytes(&mut salt);
        let key = derive(new, &salt, self.cost)?;
        let _lock = DirLock::acquire(&self.dir)?;
        let previous = (self.salt, std::mem::replace(&mut self.key, key));
        self.salt = salt;
        if let Err(e) = self.write_locked(plaintext) {
            (self.salt, self.key) = previous;
            return Err(e);
        }
        Ok(())
    }

    fn write_locked(&self, plaintext: &[u8]) -> Result<()> {
        let nonce = XChaCha20Poly1305::generate_nonce(&mut OsRng);
        let ciphertext = XChaCha20Poly1305::new(self.key.as_ref().into())
            .encrypt(
                &nonce,
                Payload {
                    msg: plaintext,
                    aad: &aad(self.cost, &self.salt),
                },
            )
            .map_err(|_| anyhow::anyhow!("vault encryption failed"))?;
        let file = VaultFile {
            format: FORMAT.into(),
            kdf: Kdf {
                alg: "argon2id".into(),
                cost: self.cost,
                salt: B64.encode(self.salt),
            },
            cipher: CIPHER.into(),
            nonce: B64.encode(nonce),
            ciphertext: B64.encode(ciphertext),
        };
        atomic_write(&self.dir, &serde_json::to_vec_pretty(&file)?)
    }
}

/// LEZ `StorageBackend` over a [`Vault`]. LEZ saves after every synced block;
/// this keeps the newest bytes in memory and writes at most once per
/// `interval`, plus on [`EncryptedBackend::flush`] (call it on lock/exit).
pub struct EncryptedBackend {
    vault: Vault,
    interval: Duration,
    state: Mutex<Pending>,
}

struct Pending {
    bytes: Option<Zeroizing<Vec<u8>>>,
    last_write: Option<Instant>,
}

impl EncryptedBackend {
    pub fn new(vault: Vault, interval: Duration) -> Self {
        Self {
            vault,
            interval,
            state: Mutex::new(Pending {
                bytes: None,
                last_write: None,
            }),
        }
    }

    /// Write any pending bytes now.
    pub fn flush(&self) -> Result<()> {
        let mut state = self
            .state
            .lock()
            .map_err(|_| anyhow::anyhow!("vault backend poisoned"))?;
        if let Some(bytes) = state.bytes.take() {
            self.vault.save(&bytes)?;
            state.last_write = Some(Instant::now());
        }
        Ok(())
    }
}

impl wallet::storage::StorageBackend for EncryptedBackend {
    fn load(&self) -> Result<Option<Vec<u8>>> {
        let state = self
            .state
            .lock()
            .map_err(|_| anyhow::anyhow!("vault backend poisoned"))?;
        if let Some(bytes) = &state.bytes {
            return Ok(Some(bytes.to_vec()));
        }
        drop(state);
        // The session key is already derived, so re-reading runs no KDF.
        Ok(Some(self.reread()?.to_vec()))
    }

    fn save(&self, bytes: &[u8]) -> Result<()> {
        let mut state = self
            .state
            .lock()
            .map_err(|_| anyhow::anyhow!("vault backend poisoned"))?;
        state.bytes = Some(Zeroizing::new(bytes.to_vec()));
        let due = state
            .last_write
            .is_none_or(|t| t.elapsed() >= self.interval);
        if due {
            let pending = state.bytes.take();
            if let Some(pending) = pending {
                self.vault.save(&pending)?;
                state.last_write = Some(Instant::now());
            }
        }
        Ok(())
    }
}

impl EncryptedBackend {
    /// Decrypt the file with the session key (no KDF run).
    fn reread(&self) -> Result<Zeroizing<Vec<u8>>> {
        let _lock = DirLock::acquire(&self.vault.dir)?;
        let file: VaultFile = serde_json::from_slice(&fs::read(self.vault.dir.join(VAULT_FILE))?)?;
        let nonce_bytes = B64.decode(&file.nonce)?;
        ensure!(nonce_bytes.len() == 24, "vault nonce must be 24 bytes");
        let plaintext = XChaCha20Poly1305::new(self.vault.key.as_ref().into())
            .decrypt(
                XNonce::from_slice(&nonce_bytes),
                Payload {
                    msg: &B64.decode(&file.ciphertext)?,
                    aad: &aad(self.vault.cost, &self.vault.salt),
                },
            )
            .map_err(|_| anyhow::anyhow!("vault changed on disk under a different key"))?;
        Ok(Zeroizing::new(plaintext))
    }
}
