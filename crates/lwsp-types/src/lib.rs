//! LWS-0 wire types for the Rust side (wallet engine, CLI, module shim).
//!
//! `generated.rs` is produced by `cargo xtask types` from
//! `protocol/schema/lws0.schema.json`; edit the TypeBox sources in
//! `protocol/src/schema/`, run `pnpm --filter @logos-kit/protocol emit`, then
//! regenerate. Pattern-constrained strings validate on deserialize.
#![allow(clippy::all, reason = "generated code")]

mod generated;

pub use generated::*;
