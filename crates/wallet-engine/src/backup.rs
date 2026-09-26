//! Encrypted backups.
//!
//! A backup is the wallet's vault files, byte for byte, in one JSON bundle:
//! the keys vault (recovery phrase, zone keys, labels, grants, tracked
//! tokens) and each zone vault (synced private state, imported keys). They
//! are already encrypted under the wallet password (keys) and the zone keys
//! it holds, so nothing is decrypted to make a backup, and restoring one
//! needs the password it was made with.

use std::{collections::BTreeMap, path::Path};

use anyhow::{Context as _, Result, bail, ensure};
use base64::{Engine as _, engine::general_purpose::STANDARD};
use serde::{Deserialize, Serialize};

use crate::{
    session::{DataDir, Session},
    vault::{atomic_write, private_dir},
};

const FORMAT: &str = "logos-kit.backup.v1";
const MAX_FILE: usize = 64 * 1024 * 1024;

#[derive(Serialize, Deserialize)]
struct Bundle {
    format: String,
    /// Relative path → base64 file bytes.
    files: BTreeMap<String, String>,
}

/// Only these files travel, so an import can't write anywhere else.
fn allowed(path: &str) -> bool {
    let parts: Vec<&str> = path.split('/').collect();
    let zone_ok = |id: &str| {
        !id.is_empty()
            && id
                .bytes()
                .all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || b == b'-' || b == b'_')
    };
    match parts[..] {
        ["zones.json"] | ["keys", "vault.json"] => true,
        ["zones", id, "vault.json" | "wallet_config.json"] => zone_ok(id),
        _ => false,
    }
}

impl DataDir {
    fn backup_files(&self) -> Result<Vec<String>> {
        let mut files = vec!["keys/vault.json".to_owned()];
        if self.root().join("zones.json").exists() {
            files.push("zones.json".to_owned());
        }
        let zones = self.root().join("zones");
        if zones.is_dir() {
            for entry in std::fs::read_dir(&zones)? {
                let entry = entry?;
                let id = entry.file_name().to_string_lossy().into_owned();
                for f in ["vault.json", "wallet_config.json"] {
                    let rel = format!("zones/{id}/{f}");
                    if allowed(&rel) && entry.path().join(f).is_file() {
                        files.push(rel);
                    }
                }
            }
        }
        Ok(files)
    }

    /// Write the files of `bundle` into this empty data dir. Everything is
    /// validated before anything is written. Returns the files written, so a
    /// caller can remove exactly those if the password then doesn't open it.
    pub fn import_backup(&self, bundle: &[u8]) -> Result<Vec<std::path::PathBuf>> {
        for existing in ["keys", "zones", "zones.json"] {
            ensure!(
                !self.root().join(existing).exists(),
                "{} already holds wallet data ({existing}); import into an empty directory",
                self.root().display()
            );
        }
        let bundle: Bundle = serde_json::from_slice(bundle).context("not a Logos Kit backup")?;
        ensure!(
            bundle.format == FORMAT,
            "unsupported backup format {}",
            bundle.format
        );
        ensure!(
            bundle.files.contains_key("keys/vault.json"),
            "the backup has no keys vault"
        );
        let mut files = Vec::with_capacity(bundle.files.len());
        for (path, b64) in &bundle.files {
            if !allowed(path) {
                bail!("the backup contains an unexpected file: {path}");
            }
            let bytes = STANDARD
                .decode(b64)
                .with_context(|| format!("{path} is not base64"))?;
            ensure!(bytes.len() <= MAX_FILE, "{path} is too large");
            files.push((self.root().join(path), bytes));
        }
        let mut written = Vec::with_capacity(files.len());
        for (full, bytes) in files {
            let dir = full.parent().context("path has a parent")?;
            let name = full.file_name().context("path has a file name")?;
            let step = ensure_private_tree(self.root(), dir)
                .and_then(|()| atomic_write(dir, &name.to_string_lossy(), &bytes));
            if let Err(e) = step {
                remove_written(self.root(), &written);
                return Err(e);
            }
            written.push(full);
        }
        Ok(written)
    }
}

/// Remove files an import wrote, then any directories it left empty.
pub fn remove_written(root: &Path, written: &[std::path::PathBuf]) {
    for f in written {
        let _ = std::fs::remove_file(f);
        let mut dir = f.parent();
        while let Some(d) = dir {
            if d == root || std::fs::remove_dir(d).is_err() {
                break;
            }
            dir = d.parent();
        }
    }
}

fn ensure_private_tree(root: &Path, dir: &Path) -> Result<()> {
    private_dir(root)?;
    let mut at = root.to_path_buf();
    for part in dir.strip_prefix(root)?.components() {
        at.push(part);
        private_dir(&at)?;
    }
    Ok(())
}

impl Session {
    /// The encrypted backup bundle (saves pending changes first).
    pub fn export_backup(&self) -> Result<Vec<u8>> {
        self.persist_now()?;
        let data = self.data_dir();
        let mut files = BTreeMap::new();
        for rel in data.backup_files()? {
            let bytes = std::fs::read(data.root().join(&rel)).with_context(|| rel.clone())?;
            files.insert(rel, STANDARD.encode(bytes));
        }
        Ok(serde_json::to_vec(&Bundle {
            format: FORMAT.to_owned(),
            files,
        })?)
    }
}

#[cfg(test)]
mod tests {
    use super::allowed;

    #[test]
    fn only_vault_files_are_allowed() {
        assert!(allowed("keys/vault.json"));
        assert!(allowed("zones/lez-local/vault.json"));
        assert!(!allowed("zones/../keys/vault.json"));
        assert!(!allowed("zones/Lez/vault.json"));
        assert!(!allowed("/etc/passwd"));
        assert!(!allowed("zones/lez-local/.session.lock"));
    }
}
