//! A wallet session: our data dir, zones, and one LEZ `WalletCore` whose
//! storage lives in an encrypted vault.
//!
//! Layout (never `~/.lee/wallet`; the official CLI keeps its own):
//!
//! ```text
//! <data>/keys/vault.json            vault.v1: the recovery phrase
//! <data>/zones.json                 zones we know (id, CAIP-2 chain, sequencer)
//! <data>/zones/<zone>/vault.json    vault.v1: LEZ Storage for that zone
//! <data>/zones/<zone>/wallet_config.json, statistics.json
//! ```
//!
//! Keys are split from per-zone state because LEZ's `Storage` carries sync
//! position and private-account state for one chain. Adding a zone (the
//! LP-0022 hook) restores the same phrase into a fresh zone vault, so the
//! accounts match everywhere while each zone syncs on its own. One password
//! unlocks both vaults.

use std::{
    path::{Path, PathBuf},
    sync::Arc,
    time::Duration,
};

use anyhow::{Context as _, Result, ensure};
use serde::{Deserialize, Serialize};
use wallet::{
    WalletCore,
    config::{SequencerConnectionData, WalletConfig},
    storage::{Storage, StorageBackend},
    sync_observer::SyncObserver,
};
use zeroize::Zeroizing;

use crate::vault::{EncryptedBackend, KdfCost, Vault, atomic_write, private_dir};

/// How often LEZ's save-per-block may hit the disk (the rest is buffered).
const SAVE_INTERVAL: Duration = Duration::from_secs(5);

/// A LEZ zone the wallet talks to.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct Zone {
    /// Directory-safe id, e.g. `lez-testnet`.
    pub id: String,
    /// CAIP-2 chain id, e.g. `lez:testnet`.
    pub chain: String,
    pub sequencer: String,
}

impl Zone {
    pub fn testnet() -> Self {
        Self {
            id: "lez-testnet".into(),
            chain: "lez:testnet".into(),
            sequencer: "https://testnet.lez.logos.co".into(),
        }
    }

    pub fn local() -> Self {
        Self {
            id: "lez-local".into(),
            chain: "lez:local".into(),
            sequencer: "http://127.0.0.1:3040".into(),
        }
    }

    fn check(&self) -> Result<()> {
        ensure!(
            !self.id.is_empty()
                && self
                    .id
                    .bytes()
                    .all(|b| b.is_ascii_alphanumeric() || b == b'-' || b == b'_'),
            "zone id must be letters, digits, '-' or '_'"
        );
        ensure!(
            self.chain.starts_with("lez:"),
            "zone chain must be a CAIP-2 lez:* id"
        );
        ensure!(
            self.sequencer.starts_with("https://") || self.sequencer.starts_with("http://"),
            "sequencer must be an http(s) URL"
        );
        // Parse exactly as LEZ will, so a bad URL fails before anything is written.
        serde_json::from_value::<SequencerConnectionData>(
            serde_json::json!({ "sequencer_addr": self.sequencer }),
        )
        .context("sequencer URL")?;
        Ok(())
    }
}

/// The wallet's data directory.
#[derive(Clone, Debug)]
pub struct DataDir(PathBuf);

impl DataDir {
    pub fn new(root: impl Into<PathBuf>) -> Self {
        Self(root.into())
    }

    pub fn root(&self) -> &Path {
        &self.0
    }

    fn keys(&self) -> PathBuf {
        self.0.join("keys")
    }

    fn zone(&self, id: &str) -> PathBuf {
        self.0.join("zones").join(id)
    }

    /// Undo a create/restore that failed after writing the keys vault, so no
    /// wallet exists whose recovery phrase the user never saw.
    fn forget_partial(&self) {
        let _ = std::fs::remove_dir_all(self.keys());
    }

    pub fn is_initialized(&self) -> bool {
        Vault::exists(&self.keys())
    }

    pub fn zones(&self) -> Result<Vec<Zone>> {
        match std::fs::read(self.0.join("zones.json")) {
            Ok(bytes) => Ok(serde_json::from_slice(&bytes).context("zones.json")?),
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(Vec::new()),
            Err(e) => Err(e.into()),
        }
    }

    fn remember_zone(&self, zone: &Zone) -> Result<()> {
        let mut zones = self.zones()?;
        zones.retain(|z| z.id != zone.id);
        zones.push(zone.clone());
        private_dir(&self.0)?;
        atomic_write(&self.0, "zones.json", &serde_json::to_vec_pretty(&zones)?)?;
        Ok(())
    }

    fn write_zone_config(&self, zone: &Zone) -> Result<PathBuf> {
        let dir = self.zone(&zone.id);
        private_dir(&dir)?;
        let config = WalletConfig {
            sequencers: vec![SequencerConnectionData {
                sequencer_addr: zone.sequencer.parse()?,
                basic_auth: None,
            }],
            ..WalletConfig::default()
        };
        atomic_write(
            &dir,
            "wallet_config.json",
            &serde_json::to_vec_pretty(&config)?,
        )?;
        Ok(dir.join("wallet_config.json"))
    }
}

/// Hands LEZ a shared handle to our backend, so the session can still flush it.
struct Shared(Arc<EncryptedBackend>);

impl StorageBackend for Shared {
    fn load(&self) -> Result<Option<Vec<u8>>> {
        self.0.load()
    }

    fn save(&self, bytes: &[u8]) -> Result<()> {
        self.0.save(bytes)
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct AccountInfo {
    pub account_id: String,
    pub kind: AccountKind,
    /// Key-tree path, e.g. `/0`.
    pub path: Option<String>,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum AccountKind {
    Public,
    Private,
}

/// The chain link. Keys and accounts live in `Storage`, so create, restore,
/// unlock and account derivation work offline; `WalletCore` (which needs a
/// reachable sequencer) is built on [`Session::connect`] and takes the storage.
enum Link {
    Offline(Box<Storage>),
    Online(Box<WalletCore>),
    /// Only observable if `connect` panicked mid-swap.
    Poisoned,
}

pub struct Session {
    data: DataDir,
    zone: Zone,
    dir: PathBuf,
    config_path: PathBuf,
    link: Link,
    backend: Arc<EncryptedBackend>,
}

impl Session {
    /// New wallet: fresh recovery phrase, keys vault, first zone. Returns the
    /// phrase once so the UI can show it for backup. Works offline.
    pub fn create(
        data: DataDir,
        password: &str,
        zone: Zone,
        cost: KdfCost,
    ) -> Result<(Self, Zeroizing<String>)> {
        ensure!(
            !data.is_initialized(),
            "a wallet already exists in {}",
            data.root().display()
        );
        zone.check()?;
        let (storage, mnemonic) = Storage::new("")?;
        let phrase = Zeroizing::new(mnemonic.to_string());
        Vault::create(data.keys(), password, phrase.as_bytes(), cost)?;
        let session = Self::open_zone(data.clone(), zone, password, Some(storage), cost)
            .inspect_err(|_| data.forget_partial())?;
        Ok((session, phrase))
    }

    /// Restore from a recovery phrase (e.g. one made by the official LEZ wallet). Works offline.
    pub fn restore(
        data: DataDir,
        password: &str,
        phrase: &str,
        zone: Zone,
        cost: KdfCost,
    ) -> Result<Self> {
        ensure!(
            !data.is_initialized(),
            "a wallet already exists in {}",
            data.root().display()
        );
        zone.check()?;
        let mnemonic = bip39::Mnemonic::parse(phrase).context("invalid recovery phrase")?;
        let phrase = Zeroizing::new(mnemonic.to_string());
        Vault::create(data.keys(), password, phrase.as_bytes(), cost)?;
        Self::open_zone(data.clone(), zone, password, None, cost)
            .inspect_err(|_| data.forget_partial())
    }

    /// Unlock an existing wallet on one of its zones (added if new). Works offline.
    pub fn unlock(data: DataDir, password: &str, zone: Zone) -> Result<Self> {
        zone.check()?;
        // Proves the password before touching any zone state.
        Vault::unlock(data.keys(), password)?;
        Self::open_zone(data, zone, password, None, KdfCost::DEFAULT)
    }

    fn open_zone(
        data: DataDir,
        zone: Zone,
        password: &str,
        fresh: Option<Storage>,
        cost: KdfCost,
    ) -> Result<Self> {
        let dir = data.zone(&zone.id);
        let config_path = data.write_zone_config(&zone)?;
        data.remember_zone(&zone)?;

        let (vault, storage) = if Vault::exists(&dir) {
            let (vault, bytes) = Vault::unlock(&dir, password)?;
            (vault, Storage::from_bytes(&bytes)?)
        } else {
            let storage = match fresh {
                Some(storage) => storage,
                None => {
                    // A zone we haven't seen: derive its storage from the phrase.
                    let (_, phrase) = Vault::unlock(data.keys(), password)?;
                    let phrase = std::str::from_utf8(&phrase).context("keys vault")?;
                    let mnemonic = bip39::Mnemonic::parse(phrase).context("keys vault phrase")?;
                    let (mut storage, _) = Storage::new("")?;
                    storage.restore(&mnemonic, "")?;
                    storage
                }
            };
            (
                Vault::create(&dir, password, &Zeroizing::new(storage.to_bytes()?), cost)?,
                storage,
            )
        };

        let backend = Arc::new(EncryptedBackend::new(vault, SAVE_INTERVAL)?);
        Ok(Self {
            data,
            zone,
            dir,
            config_path,
            link: Link::Offline(Box::new(storage)),
            backend,
        })
    }

    /// Reach the zone's sequencer. On failure the session stays offline and
    /// usable (accounts, receive codes); the error says why.
    pub async fn connect(&mut self) -> Result<()> {
        let storage = match std::mem::replace(&mut self.link, Link::Poisoned) {
            Link::Offline(storage) => *storage,
            online => {
                self.link = online;
                return Ok(());
            }
        };
        // Keep a copy: WalletCore::new consumes the storage even when it fails.
        let fallback = Storage::from_bytes(&Zeroizing::new(storage.to_bytes()?))?;
        match WalletCore::new_with_storage_backend(
            self.config_path.clone(),
            // LEZ installs a plaintext FileBackend at this path before swapping
            // in ours; point it somewhere nothing ever reads, never the vault.
            self.dir.join(".lez-storage-unused"),
            self.dir.join("statistics.json"),
            None,
            storage,
            Box::new(Shared(Arc::clone(&self.backend))),
        )
        .await
        {
            Ok(core) => {
                self.link = Link::Online(Box::new(core));
                Ok(())
            }
            Err(e) => {
                self.link = Link::Offline(Box::new(fallback));
                Err(e.context(format!("can't reach {}", self.zone.sequencer)))
            }
        }
    }

    pub const fn is_online(&self) -> bool {
        matches!(self.link, Link::Online(_))
    }

    pub const fn zone(&self) -> &Zone {
        &self.zone
    }

    pub const fn data_dir(&self) -> &DataDir {
        &self.data
    }

    /// The LEZ wallet, once connected.
    pub fn core(&self) -> Option<&WalletCore> {
        match &self.link {
            Link::Online(core) => Some(core),
            _ => None,
        }
    }

    pub fn core_mut(&mut self) -> Option<&mut WalletCore> {
        match &mut self.link {
            Link::Online(core) => Some(core),
            _ => None,
        }
    }

    fn storage(&self) -> Result<&Storage> {
        match &self.link {
            Link::Offline(storage) => Ok(storage),
            Link::Online(core) => Ok(core.storage()),
            Link::Poisoned => {
                anyhow::bail!("session is unusable after a failed connect; unlock again")
            }
        }
    }

    fn storage_mut(&mut self) -> Result<&mut Storage> {
        match &mut self.link {
            Link::Offline(storage) => Ok(storage),
            Link::Online(core) => Ok(core.storage_mut()),
            Link::Poisoned => {
                anyhow::bail!("session is unusable after a failed connect; unlock again")
            }
        }
    }

    pub fn accounts(&self) -> Result<Vec<AccountInfo>> {
        let keys = self.storage()?.key_chain();
        let public = keys.public_account_ids().map(|(id, path)| AccountInfo {
            account_id: id.to_string(),
            kind: AccountKind::Public,
            path: path.map(ToString::to_string),
        });
        let private = keys.private_account_ids().map(|(id, path)| AccountInfo {
            account_id: id.to_string(),
            kind: AccountKind::Private,
            path: path.map(ToString::to_string),
        });
        Ok(public.chain(private).collect())
    }

    /// Derive the next account of `kind` (the same key-chain calls LEZ's
    /// `WalletCore::create_new_account_*` make) and persist it right away.
    pub fn new_account(&mut self, kind: AccountKind) -> Result<AccountInfo> {
        let keys = self.storage_mut()?.key_chain_mut();
        let (id, path) = match kind {
            AccountKind::Public => keys.generate_new_public_transaction_private_key(None),
            AccountKind::Private => {
                keys.generate_new_privacy_preserving_transaction_key_chain(None)
            }
        };
        self.persist_now()?;
        Ok(AccountInfo {
            account_id: id.to_string(),
            kind,
            path: Some(path.to_string()),
        })
    }

    /// Sync this zone to the sequencer's latest block (connects if needed).
    pub async fn sync(&mut self, observer: &mut dyn SyncObserver) -> Result<u64> {
        self.connect().await?;
        let core = self.core_mut().context("not connected")?;
        let result = core.sync_to_latest_block_with_observer(observer).await;
        // Persist whatever was synced, even if sync stopped part-way.
        self.backend.flush()?;
        result
    }

    /// Write the current storage to the vault now (not debounced).
    pub fn persist_now(&self) -> Result<()> {
        self.storage()?
            .save_to(&Shared(Arc::clone(&self.backend)))?;
        self.backend.flush()
    }

    /// Flush and drop the session (keys leave memory with it).
    pub fn lock(self) -> Result<()> {
        self.backend.flush()
    }
}
