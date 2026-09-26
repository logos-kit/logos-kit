//! Who may do what. The engine is the policy authority; the module shim only
//! reports who called (`current_caller()` in Basecamp).
//!
//! - **WalletUi**: our own wallet UI module. The only caller that can approve,
//!   and it relays the shell-attested `requesterName` of the app it serves.
//! - **LocalOwner**: the `logos-kit` CLI on the owner's machine (it asks for
//!   confirmation on the terminal itself).
//! - **Module(name)**: any other Basecamp module (a dApp calling us directly).
//!   Reads and proposals need a grant; it can never approve, sign or submit.
//! - **Host / Bridge / Unknown**: fail closed.
//!
//! Grant keys follow the S0 identity-hop probe: the shell's `requesterName`
//! and `current_caller()` name a module the same way, so one grant serves a
//! dApp's intents and its direct calls.

use std::fmt;

use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Caller {
    WalletUi,
    LocalOwner,
    Module(String),
    Host,
    Bridge,
    Unknown,
}

impl Caller {
    /// May approve, reject any request, manage grants and see every status.
    pub const fn is_owner(&self) -> bool {
        matches!(self, Self::WalletUi | Self::LocalOwner)
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Capability {
    Accounts,
    ReadPublic,
    ReadPrivate,
    ProposeTx,
    SignMessage,
    RequestProof,
}

/// One permission: `requester` may use `capability` on `account` in `zone`.
#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Grant {
    pub zone: String,
    pub requester: String,
    pub account: String,
    pub capability: Capability,
}

pub fn allows(
    grants: &[Grant],
    zone: &str,
    requester: &str,
    account: &str,
    cap: Capability,
) -> bool {
    grants.iter().any(|g| {
        g.zone == zone && g.requester == requester && g.account == account && g.capability == cap
    })
}

/// LWS-0 error codes (protocol/src/errors.ts) the engine returns.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
#[repr(i64)]
pub enum Code {
    UserRejected = 4001,
    Unauthorized = 4100,
    ChainDisconnected = 4901,
    InvalidParams = -32602,
    Internal = -32603,
    UnknownHandle = 5730,
    ProofFailed = 6102,
    SubmissionFailed = 6103,
    StaleApproval = 6106,
    RequestPending = 6107,
    Timeout = 6108,
}

/// An error with its LWS-0 code, carried inside `anyhow::Error`.
#[derive(Debug)]
pub struct Denied {
    pub code: Code,
    pub message: String,
}

impl Denied {
    pub fn err(code: Code, message: impl Into<String>) -> anyhow::Error {
        Self {
            code,
            message: message.into(),
        }
        .into()
    }
}

impl fmt::Display for Denied {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.message)
    }
}

impl std::error::Error for Denied {}

/// The LWS-0 code for any engine error (for the C ABI and the CLI's exit status).
pub fn code_of(e: &anyhow::Error) -> Code {
    if let Some(d) = e.downcast_ref::<Denied>() {
        d.code
    } else if e.downcast_ref::<crate::tx::Stale>().is_some() {
        Code::StaleApproval
    } else if e.downcast_ref::<crate::auto_lock::Locked>().is_some() {
        Code::Unauthorized
    } else if e.downcast_ref::<crate::session::Offline>().is_some() {
        Code::ChainDisconnected
    } else {
        Code::Internal
    }
}
