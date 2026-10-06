//! Before a local proof: is there enough free memory, and how big are the
//! segments.
//!
//! A private transaction proves inside the host's process (Basecamp, or the
//! CLI). At risc0's default segment size (2^20 cycles) the privacy circuit
//! peaks at about 4.3 GB on an M-series Mac; running out of memory there
//! kills the host, so the wallet checks first and says why it won't start.
//! Low-memory mode proves with 2^18-cycle segments (LEZ patch 0008): less
//! memory, more time.

use std::sync::atomic::{AtomicBool, Ordering};

use anyhow::Result;

use crate::policy::{Code, Denied};

/// Free memory a default proof needs (peak measured 4.3 GB, plus headroom).
pub const NEEDS_DEFAULT: u64 = 4_600 * MIB;
/// Free memory a low-memory proof needs (2^18 segments; budget, see
/// docs/dev/perf.md for the measured peak).
pub const NEEDS_LOW_MEMORY: u64 = 2_000 * MIB;
/// Segment size in low-memory mode.
pub const LOW_MEMORY_PO2: u32 = 18;

const MIB: u64 = 1024 * 1024;

static LOW_MEMORY: AtomicBool = AtomicBool::new(false);

/// The host's setting (Settings → Proving, or `--low-memory` on the CLI).
pub fn set_low_memory(on: bool) {
    LOW_MEMORY.store(on, Ordering::Relaxed);
}

pub fn low_memory() -> bool {
    LOW_MEMORY.load(Ordering::Relaxed)
}

/// Check free memory and set the segment size for the proof about to start.
/// A refusal says how much is free and what to do; nothing has been sent.
pub fn prepare() -> Result<()> {
    let low = low_memory();
    lee::privacy_preserving_transaction::circuit::set_segment_limit_po2(
        low.then_some(LOW_MEMORY_PO2),
    );
    let needs = if low { NEEDS_LOW_MEMORY } else { NEEDS_DEFAULT };
    if let Some(free) = available_memory()
        && free < needs
    {
        let gb = |b: u64| format!("{:.1} GB", b as f64 / (1024.0 * MIB as f64));
        let advice = if low {
            "Close other apps and try again."
        } else {
            "Close other apps, or turn on low-memory proving in Settings (slower), and try again."
        };
        return Err(Denied::err(
            Code::ProofFailed,
            format!(
                "Proving needs about {} of free memory and this computer has {} free. Nothing was sent. {advice}",
                gb(needs),
                gb(free)
            ),
        ));
    }
    Ok(())
}

/// Memory the OS could hand a new allocation now, if we can tell.
pub fn available_memory() -> Option<u64> {
    #[cfg(target_os = "linux")]
    {
        let info = std::fs::read_to_string("/proc/meminfo").ok()?;
        let kb: u64 = info
            .lines()
            .find(|l| l.starts_with("MemAvailable:"))?
            .split_whitespace()
            .nth(1)?
            .parse()
            .ok()?;
        Some(kb * 1024)
    }
    #[cfg(target_os = "macos")]
    {
        // vm_stat: free, inactive, speculative and purgeable pages can all be
        // handed out without swapping.
        let out = std::process::Command::new("/usr/bin/vm_stat")
            .output()
            .ok()?;
        parse_vm_stat(&String::from_utf8_lossy(&out.stdout))
    }
    #[cfg(not(any(target_os = "linux", target_os = "macos")))]
    {
        None
    }
}

#[cfg_attr(not(any(target_os = "macos", test)), allow(dead_code))]
fn parse_vm_stat(text: &str) -> Option<u64> {
    let page: u64 = text
        .lines()
        .next()?
        .split("page size of ")
        .nth(1)?
        .split_whitespace()
        .next()?
        .parse()
        .ok()?;
    let pages = |name: &str| -> u64 {
        text.lines()
            .find(|l| l.starts_with(name))
            .and_then(|l| l.rsplit(':').next())
            .and_then(|v| v.trim().trim_end_matches('.').parse().ok())
            .unwrap_or(0)
    };
    let free = pages("Pages free")
        + pages("Pages inactive")
        + pages("Pages speculative")
        + pages("Pages purgeable");
    Some(free * page)
}

#[cfg(test)]
mod tests {
    #[test]
    fn reads_vm_stat() {
        let text = "Mach Virtual Memory Statistics: (page size of 16384 bytes)\n\
                    Pages free:                               10000.\n\
                    Pages active:                            200000.\n\
                    Pages inactive:                           50000.\n\
                    Pages speculative:                         2000.\n\
                    Pages purgeable:                           1000.\n";
        assert_eq!(super::parse_vm_stat(text), Some(63_000 * 16_384));
    }
}
