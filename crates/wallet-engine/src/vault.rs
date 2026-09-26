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
const LOCK_FILE: &str = ".vault.lock";
/// Held for a whole session, so two processes never own one vault at once.
const SESSION_LOCK_FILE: &str = ".session.lock";
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
    /// Ceiling: a tampered header must not make unlock allocate or spin for
    /// long on a phone before the tag check fails.
    const MAX: Self = Self {
        m: 256 * 1024,
        t: 6,
        p: 4,
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

/// How the vault key is obtained, as written in the file header.
#[derive(Serialize, Deserialize)]
#[serde(tag = "alg")]
enum Kdf {
    /// The key is Argon2id(password, salt).
    #[serde(rename = "argon2id")]
    Argon2id {
        m: u32,
        t: u32,
        p: u32,
        salt: String,
    },
    /// The key is random and held inside another vault (the keys vault).
    /// `context` names what this vault is for (e.g. `zone:lez-testnet`).
    #[serde(rename = "none")]
    Keyed { context: String },
}

#[derive(Serialize, Deserialize)]
struct VaultFile {
    format: String,
    kdf: Kdf,
    cipher: String,
    nonce: String,
    ciphertext: String,
}

/// How an unlocked vault was sealed.
#[derive(Clone, Debug)]
enum Seal {
    Password { cost: KdfCost, salt: [u8; 16] },
    Keyed { context: String },
}

impl Seal {
    /// The associated data: a fixed-order rendering of everything but the
    /// nonce and ciphertext (so it doesn't depend on a JSON serializer's key
    /// order). A keyed vault binds its context, so one zone's file can't be
    /// swapped in for another's.
    fn aad(&self) -> Vec<u8> {
        match self {
            Self::Password { cost, salt } => format!(
                "{FORMAT}|argon2id|m={}|t={}|p={}|salt={}|{CIPHER}",
                cost.m,
                cost.t,
                cost.p,
                B64.encode(salt)
            ),
            Self::Keyed { context } => format!("{FORMAT}|keyed|context={context}|{CIPHER}"),
        }
        .into_bytes()
    }

    fn header(&self) -> Kdf {
        match self {
            Self::Password { cost, salt } => Kdf::Argon2id {
                m: cost.m,
                t: cost.t,
                p: cost.p,
                salt: B64.encode(salt),
            },
            Self::Keyed { context } => Kdf::Keyed {
                context: context.clone(),
            },
        }
    }
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

/// A fresh random 32-byte key for a keyed vault.
pub fn new_key() -> Zeroizing<[u8; 32]> {
    let mut key = Zeroizing::new([0_u8; 32]);
    OsRng.fill_bytes(key.as_mut());
    key
}

/// An advisory lock on a file in the vault dir, released on drop. Opened
/// without following symlinks, owner-only.
struct FileLock(File);

impl FileLock {
    fn acquire(path: &Path, wait: Duration, busy: &str) -> Result<Self> {
        let mut opts = OpenOptions::new();
        opts.create(true).truncate(false).write(true);
        #[cfg(unix)]
        {
            use std::os::unix::fs::OpenOptionsExt as _;
            opts.mode(0o600).custom_flags(O_NOFOLLOW);
        }
        let file = opts
            .open(path)
            .with_context(|| format!("open lock {}", path.display()))?;
        let start = Instant::now();
        loop {
            match file.try_lock() {
                Ok(()) => return Ok(Self(file)),
                Err(fs::TryLockError::WouldBlock) if start.elapsed() < wait => {
                    std::thread::sleep(Duration::from_millis(25));
                }
                Err(fs::TryLockError::WouldBlock) => bail!("{busy}"),
                Err(fs::TryLockError::Error(e)) => return Err(e.into()),
            }
        }
    }
}

impl Drop for FileLock {
    fn drop(&mut self) {
        let _ = self.0.unlock();
    }
}

/// `O_NOFOLLOW`: refuse to open a lock path that is a symlink.
#[cfg(any(target_os = "macos", target_os = "ios"))]
const O_NOFOLLOW: i32 = 0x0100;
#[cfg(all(unix, not(any(target_os = "macos", target_os = "ios"))))]
const O_NOFOLLOW: i32 = 0o400_000;

/// Held while reading or writing one vault file (short).
fn write_lock(dir: &Path) -> Result<FileLock> {
    FileLock::acquire(
        &dir.join(LOCK_FILE),
        LOCK_WAIT,
        "another Logos Kit process is writing the vault",
    )
}

/// Create `path` (and parents) owner-only (0700 on unix).
pub fn private_dir(path: &Path) -> Result<()> {
    let mut builder = fs::DirBuilder::new();
    builder.recursive(true);
    #[cfg(unix)]
    {
        use std::os::unix::fs::DirBuilderExt as _;
        builder.mode(0o700);
    }
    builder
        .create(path)
        .with_context(|| format!("create {}", path.display()))
}

/// Atomically replace `dir/name` with `bytes`: a fresh randomly named temp
/// file (exclusive create, 0600 on unix, so no pre-planted file or symlink is
/// ever written through), fsync, rename, fsync the directory. A crash leaves
/// the old file or the new one, never a torn one.
pub fn atomic_write(dir: &Path, name: &str, bytes: &[u8]) -> Result<()> {
    let mut tmp = tempfile::Builder::new()
        .prefix(".staged-")
        .tempfile_in(dir)?;
    tmp.write_all(bytes)?;
    tmp.as_file().sync_all()?;
    tmp.persist(dir.join(name)).map_err(|e| e.error)?;
    // Without this the rename is atomic but may not survive power loss.
    #[cfg(unix)]
    File::open(dir)?.sync_all()?;
    Ok(())
}

/// An unlocked vault: the directory plus the key for this session.
pub struct Vault {
    dir: PathBuf,
    seal: Seal,
    key: Zeroizing<[u8; 32]>,
}

impl Vault {
    pub fn exists(dir: &Path) -> bool {
        dir.join(VAULT_FILE).is_file()
    }

    /// Create a new password-sealed vault holding `plaintext`. Fails if one already exists.
    pub fn create(
        dir: impl Into<PathBuf>,
        password: &str,
        plaintext: &[u8],
        cost: KdfCost,
    ) -> Result<Self> {
        let mut salt = [0_u8; 16];
        OsRng.fill_bytes(&mut salt);
        let key = derive(password, &salt, cost.check()?)?;
        Self::create_sealed(dir.into(), Seal::Password { cost, salt }, key, plaintext)
    }

    /// Create a new vault sealed by `key` (held in another vault) and bound to
    /// `context`. Fails if one already exists.
    pub fn create_keyed(
        dir: impl Into<PathBuf>,
        key: Zeroizing<[u8; 32]>,
        context: &str,
        plaintext: &[u8],
    ) -> Result<Self> {
        let seal = Seal::Keyed {
            context: context.to_owned(),
        };
        Self::create_sealed(dir.into(), seal, key, plaintext)
    }

    fn create_sealed(
        dir: PathBuf,
        seal: Seal,
        key: Zeroizing<[u8; 32]>,
        plaintext: &[u8],
    ) -> Result<Self> {
        private_dir(&dir)?;
        let _lock = write_lock(&dir)?;
        ensure!(
            !Self::exists(&dir),
            "a vault already exists in {}",
            dir.display()
        );
        let vault = Self { dir, seal, key };
        vault.write_locked(plaintext)?;
        Ok(vault)
    }

    /// Unlock a password-sealed vault: derive the key and decrypt. A wrong
    /// password and a tampered file both fail the AEAD tag with the same error.
    pub fn unlock(dir: impl Into<PathBuf>, password: &str) -> Result<(Self, Zeroizing<Vec<u8>>)> {
        let dir = dir.into();
        let _lock = write_lock(&dir)?;
        let file = read_file(&dir)?;
        let Kdf::Argon2id { m, t, p, salt } = &file.kdf else {
            bail!("this vault is not unlocked by a password");
        };
        let cost = KdfCost {
            m: *m,
            t: *t,
            p: *p,
        }
        .check()?;
        let salt: [u8; 16] = B64
            .decode(salt)?
            .try_into()
            .map_err(|_| anyhow::anyhow!("vault salt must be 16 bytes"))?;
        let vault = Self {
            dir,
            seal: Seal::Password { cost, salt },
            key: derive(password, &salt, cost)?,
        };
        let plaintext = vault
            .open(&file)
            .map_err(|_| anyhow::anyhow!("wrong password or damaged vault"))?;
        Ok((vault, plaintext))
    }

    /// Unlock a keyed vault. `context` must match the one it was created with.
    pub fn unlock_keyed(
        dir: impl Into<PathBuf>,
        key: Zeroizing<[u8; 32]>,
        context: &str,
    ) -> Result<(Self, Zeroizing<Vec<u8>>)> {
        let dir = dir.into();
        let _lock = write_lock(&dir)?;
        let file = read_file(&dir)?;
        ensure!(
            matches!(&file.kdf, Kdf::Keyed { context: c } if c == context),
            "vault in {} does not belong to {context}",
            dir.display()
        );
        let vault = Self {
            dir,
            seal: Seal::Keyed {
                context: context.to_owned(),
            },
            key,
        };
        let plaintext = vault
            .open(&file)
            .map_err(|_| anyhow::anyhow!("damaged vault in {}", vault.dir.display()))?;
        Ok((vault, plaintext))
    }

    /// Decrypt the file on disk with the session key (no KDF run).
    pub fn read(&self) -> Result<Zeroizing<Vec<u8>>> {
        let _lock = write_lock(&self.dir)?;
        self.open(&read_file(&self.dir)?)
            .map_err(|_| anyhow::anyhow!("vault changed on disk under a different key"))
    }

    fn open(&self, file: &VaultFile) -> Result<Zeroizing<Vec<u8>>> {
        let nonce = B64.decode(&file.nonce)?;
        ensure!(nonce.len() == 24, "vault nonce must be 24 bytes");
        let plaintext = XChaCha20Poly1305::new(self.key.as_ref().into())
            .decrypt(
                XNonce::from_slice(&nonce),
                Payload {
                    msg: &B64.decode(&file.ciphertext)?,
                    aad: &self.seal.aad(),
                },
            )
            .map_err(|_| anyhow::anyhow!("vault tag mismatch"))?;
        Ok(Zeroizing::new(plaintext))
    }

    /// Re-encrypt `plaintext` under the session key (new nonce every time).
    pub fn save(&self, plaintext: &[u8]) -> Result<()> {
        let _lock = write_lock(&self.dir)?;
        self.write_locked(plaintext)
    }

    /// New password: new salt, new key, same contents. `current` must match.
    /// Password-sealed vaults only.
    pub fn change_password(&mut self, current: &str, new: &str, plaintext: &[u8]) -> Result<()> {
        let Seal::Password { cost, salt } = self.seal.clone() else {
            bail!("this vault is not unlocked by a password");
        };
        ensure!(
            *derive(current, &salt, cost)? == *self.key,
            "current password is wrong"
        );
        let mut new_salt = [0_u8; 16];
        OsRng.fill_bytes(&mut new_salt);
        let key = derive(new, &new_salt, cost)?;
        let _lock = write_lock(&self.dir)?;
        let previous = (
            std::mem::replace(
                &mut self.seal,
                Seal::Password {
                    cost,
                    salt: new_salt,
                },
            ),
            std::mem::replace(&mut self.key, key),
        );
        if let Err(e) = self.write_locked(plaintext) {
            (self.seal, self.key) = previous;
            return Err(e);
        }
        Ok(())
    }

    /// Check `password` against this password-sealed vault without touching disk.
    pub fn verify_password(&self, password: &str) -> Result<bool> {
        let Seal::Password { cost, salt } = &self.seal else {
            bail!("this vault is not unlocked by a password");
        };
        Ok(*derive(password, salt, *cost)? == *self.key)
    }

    fn write_locked(&self, plaintext: &[u8]) -> Result<()> {
        let nonce = XChaCha20Poly1305::generate_nonce(&mut OsRng);
        let ciphertext = XChaCha20Poly1305::new(self.key.as_ref().into())
            .encrypt(
                &nonce,
                Payload {
                    msg: plaintext,
                    aad: &self.seal.aad(),
                },
            )
            .map_err(|_| anyhow::anyhow!("vault encryption failed"))?;
        let file = VaultFile {
            format: FORMAT.into(),
            kdf: self.seal.header(),
            cipher: CIPHER.into(),
            nonce: B64.encode(nonce),
            ciphertext: B64.encode(ciphertext),
        };
        atomic_write(&self.dir, VAULT_FILE, &serde_json::to_vec_pretty(&file)?)
    }
}

fn read_file(dir: &Path) -> Result<VaultFile> {
    let file: VaultFile =
        serde_json::from_slice(&fs::read(dir.join(VAULT_FILE)).context("read vault")?)
            .context("vault is not valid JSON")?;
    ensure!(
        file.format == FORMAT && file.cipher == CIPHER,
        "unsupported vault format"
    );
    Ok(file)
}

/// Exclusive ownership of a wallet directory for one process's session:
/// a second process (CLI vs Basecamp module) fails fast instead of racing it.
pub struct SessionLock {
    _held: FileLock,
}

impl SessionLock {
    pub fn acquire(dir: &Path) -> Result<Self> {
        private_dir(dir)?;
        FileLock::acquire(
            &dir.join(SESSION_LOCK_FILE),
            Duration::ZERO,
            "this wallet is open in another Logos Kit process (Basecamp or the CLI); close it there first",
        )
        .map(|held| Self { _held: held })
    }
}

/// LEZ `StorageBackend` over a [`Vault`]. LEZ saves after every synced block;
/// this keeps the newest bytes in memory and writes at most once per
/// `interval`, plus on [`EncryptedBackend::flush`] and on drop.
///
/// Owns the vault's session lock for its lifetime: a second process (CLI vs
/// Basecamp module) cannot open the same zone, so neither can overwrite the
/// other's newer state or undo its password change.
pub struct EncryptedBackend {
    vault: Vault,
    interval: Duration,
    state: Mutex<Pending>,
    _session: SessionLock,
}

struct Pending {
    bytes: Option<Zeroizing<Vec<u8>>>,
    last_write: Option<Instant>,
}

impl EncryptedBackend {
    pub fn new(vault: Vault, interval: Duration) -> Result<Self> {
        let session = SessionLock::acquire(&vault.dir)?;
        Ok(Self {
            vault,
            interval,
            state: Mutex::new(Pending {
                bytes: None,
                last_write: None,
            }),
            _session: session,
        })
    }

    /// Write any pending bytes now. Pending bytes are only dropped once written.
    pub fn flush(&self) -> Result<()> {
        let mut state = self
            .state
            .lock()
            .map_err(|_| anyhow::anyhow!("vault backend poisoned"))?;
        Self::write_pending(&self.vault, &mut state)
    }

    fn write_pending(vault: &Vault, state: &mut Pending) -> Result<()> {
        if let Some(bytes) = &state.bytes {
            vault.save(bytes)?;
            state.bytes = None;
            state.last_write = Some(Instant::now());
        }
        Ok(())
    }
}

impl Drop for EncryptedBackend {
    fn drop(&mut self) {
        // Best effort: a session dropped without lock() still persists.
        if let Ok(mut state) = self.state.lock() {
            let _ = Self::write_pending(&self.vault, &mut state);
        }
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
        Ok(Some(self.vault.read()?.to_vec()))
    }

    fn save(&self, bytes: &[u8]) -> Result<()> {
        let mut state = self
            .state
            .lock()
            .map_err(|_| anyhow::anyhow!("vault backend poisoned"))?;
        state.bytes = Some(Zeroizing::new(bytes.to_vec()));
        if state
            .last_write
            .is_none_or(|t| t.elapsed() >= self.interval)
        {
            Self::write_pending(&self.vault, &mut state)?;
        }
        Ok(())
    }
}
