//! `cargo xtask lez-vendor` / `lez-export`: our patched LEZ tree.
//!
//! `vendor/lez/` (git-ignored) = LEZ at `LEZ_REV` + `vendor/lez-patches/*.patch`
//! applied with `git am`. It is a real git repo, so the edit loop is: change
//! code in vendor/lez, commit, then `lez-export` rewrites the patch files.
//! The patches are the source of truth; Nix rebuilds the same tree with
//! `applyPatches` (flake.nix), so both paths yield identical sources.

use std::{
    fs,
    path::{Path, PathBuf},
    process::Command,
};

use anyhow::{Context as _, Result, bail, ensure};

const LEZ_URL: &str = "https://github.com/logos-blockchain/logos-execution-zone";

fn git(dir: &Path, args: &[&str]) -> Result<()> {
    let status = Command::new("git")
        .arg("-C")
        .arg(dir)
        // Commits made by `git am` get a fixed identity, so the tree is reproducible.
        .env("GIT_COMMITTER_NAME", "logos-kit")
        .env("GIT_COMMITTER_EMAIL", "vendor@logos-kit.invalid")
        .env("GIT_COMMITTER_DATE", "2026-01-01T00:00:00Z")
        .args(args)
        .status()
        .with_context(|| format!("git {}", args.join(" ")))?;
    ensure!(status.success(), "git {} failed", args.join(" "));
    Ok(())
}

fn patches(root: &Path) -> Result<Vec<PathBuf>> {
    let dir = root.join("vendor/lez-patches");
    let mut out: Vec<PathBuf> = match fs::read_dir(&dir) {
        Ok(entries) => entries
            .filter_map(Result::ok)
            .map(|e| e.path())
            .filter(|p| p.extension().is_some_and(|x| x == "patch"))
            .collect(),
        Err(_) => Vec::new(),
    };
    out.sort();
    Ok(out)
}

pub fn vendor(repo_root: &Path) -> Result<()> {
    let root = repo_root.canonicalize()?;
    let dest = root.join("vendor/lez");
    if dest.join(".git").exists() {
        // Refuse to discard local work that hasn't been exported yet.
        let dirty = Command::new("git")
            .arg("-C")
            .arg(&dest)
            .args(["status", "--porcelain"])
            .output()?;
        if !dirty.stdout.is_empty() {
            bail!(
                "vendor/lez has uncommitted changes; commit + `cargo xtask lez-export`, or remove it"
            );
        }
    } else {
        fs::create_dir_all(&dest)?;
        git(&dest, &["init", "-q"])?;
        git(&dest, &["remote", "add", "origin", LEZ_URL])?;
    }
    git(
        &dest,
        &["fetch", "-q", "--depth", "1", "origin", crate::LEZ_REV],
    )?;
    git(&dest, &["checkout", "-q", "--detach", crate::LEZ_REV])?;
    git(&dest, &["reset", "-q", "--hard", crate::LEZ_REV])?;
    let list = patches(&root)?;
    if !list.is_empty() {
        let mut args = vec!["am", "-q", "--committer-date-is-author-date"];
        let paths: Vec<String> = list.iter().map(|p| p.display().to_string()).collect();
        args.extend(paths.iter().map(String::as_str));
        git(&dest, &args)?;
    }
    println!(
        "vendor/lez = LEZ {} + {} patch(es)",
        &crate::LEZ_REV[..12],
        list.len()
    );
    Ok(())
}

pub fn export(repo_root: &Path) -> Result<()> {
    let root = repo_root.canonicalize()?;
    let dest = root.join("vendor/lez");
    ensure!(
        dest.join(".git").exists(),
        "vendor/lez missing; run `cargo xtask lez-vendor`"
    );
    let out = root.join("vendor/lez-patches");
    fs::create_dir_all(&out)?;
    // Keep each patch's existing file name (matched by its `NNNN-` number), so
    // a re-export only changes contents, not names the README links to.
    let mut names = std::collections::BTreeMap::new();
    for old in patches(&root)? {
        if let Some(name) = old.file_name().and_then(|n| n.to_str()) {
            names.insert(name[..name.len().min(4)].to_owned(), name.to_owned());
        }
        fs::remove_file(old)?;
    }
    let range = format!("{}..HEAD", crate::LEZ_REV);
    git(
        &dest,
        &[
            "format-patch",
            "-q",
            "--no-signature",
            "--zero-commit",
            "--no-numbered",
            "-o",
            &out.display().to_string(),
            &range,
        ],
    )?;
    for new in patches(&root)? {
        let Some(name) = new.file_name().and_then(|n| n.to_str()) else {
            continue;
        };
        if let Some(kept) = names.get(&name[..name.len().min(4)]) {
            fs::rename(&new, out.join(kept))?;
        }
    }
    println!(
        "exported {} patch(es) to vendor/lez-patches",
        patches(&root)?.len()
    );
    Ok(())
}
