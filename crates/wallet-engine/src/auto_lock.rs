//! Auto-lock: the one place an unlocked [`Session`] lives in a host (the
//! Basecamp module, the CLI's long-running commands).
//!
//! Every use goes through [`AutoLock::session`], which locks first if the
//! wallet sat idle past its limit, so an expired session is never handed out
//! even if the host's timer is late. The host also calls [`AutoLock::tick`]
//! from a timer so the keys leave memory on time, not just on the next call.

use std::fmt;
use std::time::{Duration, Instant, SystemTime};

use anyhow::Result;

use crate::session::Session;

/// Returned (inside `anyhow::Error`) when the wallet is locked.
#[derive(Debug)]
pub struct Locked;

impl fmt::Display for Locked {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str("the wallet is locked")
    }
}

impl std::error::Error for Locked {}

/// When the session was last used, on two clocks: `Instant` is monotonic but
/// stops while the machine sleeps; wall time keeps running through sleep.
#[derive(Clone, Copy)]
struct Used {
    mono: Instant,
    wall: SystemTime,
}

impl Used {
    fn now() -> Self {
        Self {
            mono: Instant::now(),
            wall: SystemTime::now(),
        }
    }

    /// The longer of the two readings; a wall clock set backwards counts as
    /// no time passed on that clock, so the monotonic reading still applies.
    fn idle(self) -> Duration {
        let wall = self.wall.elapsed().unwrap_or(Duration::ZERO);
        self.mono.elapsed().max(wall)
    }
}

#[derive(Default)]
pub struct AutoLock {
    unlocked: Option<(Session, Used)>,
}

impl AutoLock {
    pub fn new(session: Session) -> Self {
        Self {
            unlocked: Some((session, Used::now())),
        }
    }

    /// Replace whatever is open (flushing it) with a freshly unlocked session.
    /// The new session is kept even if flushing the old one fails; that error
    /// is returned for the host to show.
    pub fn set(&mut self, session: Session) -> Result<()> {
        let flushed = self.lock();
        self.unlocked = Some((session, Used::now()));
        flushed
    }

    pub const fn is_unlocked(&self) -> bool {
        self.unlocked.is_some()
    }

    /// The session, marking it used now. Fails with [`Locked`] if the wallet
    /// is locked or its idle time just ran out.
    pub fn session(&mut self) -> Result<&mut Session> {
        // Locked either way; a failed final flush rides along as the cause.
        self.tick().map_err(|e| e.context(Locked))?;
        match &mut self.unlocked {
            Some((session, last_used)) => {
                *last_used = Used::now();
                Ok(session)
            }
            None => Err(Locked.into()),
        }
    }

    /// The session without counting this as use (background sync, UI reads).
    pub fn session_quiet(&mut self) -> Result<&mut Session> {
        self.tick().map_err(|e| e.context(Locked))?;
        match &mut self.unlocked {
            Some((session, _)) => Ok(session),
            None => Err(Locked.into()),
        }
    }

    /// Count now as use (e.g. the user just sat through a proof).
    pub fn touch(&mut self) {
        if let Some((_, last_used)) = &mut self.unlocked {
            *last_used = Used::now();
        }
    }

    /// Time left before auto-lock, if unlocked.
    pub fn remaining(&self) -> Option<Duration> {
        self.unlocked
            .as_ref()
            .map(|(session, last_used)| session.auto_lock().saturating_sub(last_used.idle()))
    }

    /// Lock if idle past the limit. Returns true when this call locked it.
    pub fn tick(&mut self) -> Result<bool> {
        if self.remaining() == Some(Duration::ZERO) {
            self.lock()?;
            return Ok(true);
        }
        Ok(false)
    }

    /// Lock now: flush and drop the session (keys leave memory with it).
    pub fn lock(&mut self) -> Result<()> {
        match self.unlocked.take() {
            Some((session, _)) => session.lock(),
            None => Ok(()),
        }
    }
}
