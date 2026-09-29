//! The drip's durable ledger: what survives a restart.
//!
//! - every request key's outcome for [`KEY_TTL`], so a retry with the same key
//!   gets the first answer and never a second payment;
//! - an **in-flight** mark written *before* paying (with the target's balance
//!   at that moment), so a crash mid-payment comes back as `outcome_unknown`
//!   (or `funded`, if the balance proves it) instead of paying again;
//! - each account's last claim (the per-account wait);
//! - the drops of the last hour (the global treasury budget).
//!
//! One JSON file, rewritten atomically (temp file, fsync, rename, dir fsync)
//! on every change. The drip is a single process; the file is its only state.

use std::{
    collections::HashMap,
    fs,
    io::Write as _,
    path::{Path, PathBuf},
    time::{SystemTime, UNIX_EPOCH},
};

use anyhow::{Context as _, Result};
use serde::{Deserialize, Serialize};
use wallet_engine::faucet::FundOutcome;

/// How long a request key's outcome is kept (matches the engine's KeyFaucet).
pub const KEY_TTL_MS: u64 = 24 * 3600 * 1000;
pub const HOUR_MS: u64 = 3600 * 1000;

pub fn now_ms() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_or(0, |d| u64::try_from(d.as_millis()).unwrap_or(u64::MAX))
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct KeyEntry {
    pub account: String,
    pub at_ms: u64,
    /// `None` while the payment is in flight.
    pub outcome: Option<FundOutcome>,
    /// The target's balance just before paying (to reconcile a crash).
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub before: Option<String>,
}

#[derive(Debug, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct State {
    pub keys: HashMap<String, KeyEntry>,
    /// Account → last claim (ms).
    pub accounts: HashMap<String, u64>,
    /// Drops paid (or possibly paid) in the last hour (ms).
    pub drops: Vec<u64>,
}

pub struct Ledger {
    path: PathBuf,
    pub state: State,
}

impl Ledger {
    pub fn open(dir: &Path) -> Result<Self> {
        fs::create_dir_all(dir).with_context(|| format!("create {}", dir.display()))?;
        let path = dir.join("ledger.json");
        let state = match fs::read(&path) {
            Ok(bytes) => serde_json::from_slice(&bytes)
                .with_context(|| format!("{} is not a drip ledger", path.display()))?,
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => State::default(),
            Err(e) => return Err(e).with_context(|| format!("read {}", path.display())),
        };
        Ok(Self { path, state })
    }

    /// Drop expired entries (keys after their TTL, accounts after `every`).
    pub fn prune(&mut self, every_ms: u64) {
        let now = now_ms();
        self.state
            .keys
            .retain(|_, e| e.outcome.is_none() || now.saturating_sub(e.at_ms) < KEY_TTL_MS);
        self.state
            .accounts
            .retain(|_, at| now.saturating_sub(*at) < every_ms);
        self.state
            .drops
            .retain(|at| now.saturating_sub(*at) < HOUR_MS);
    }

    /// Entries still in flight (left by a crash): reconcile them at start.
    pub fn in_flight(&self) -> Vec<(String, KeyEntry)> {
        self.state
            .keys
            .iter()
            .filter(|(_, e)| e.outcome.is_none())
            .map(|(k, e)| (k.clone(), e.clone()))
            .collect()
    }

    pub fn save(&self) -> Result<()> {
        let dir = self.path.parent().unwrap_or(Path::new("."));
        let tmp = dir.join(format!(".ledger.{}.tmp", std::process::id()));
        {
            let mut f = fs::File::create(&tmp)?;
            f.write_all(&serde_json::to_vec(&self.state)?)?;
            f.sync_all()?;
        }
        fs::rename(&tmp, &self.path)?;
        if let Ok(d) = fs::File::open(dir) {
            let _ = d.sync_all();
        }
        Ok(())
    }
}
