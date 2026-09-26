# LEZ `wallet` crate patches (Logos Kit)

Small, upstreamable patch series against the LEZ `wallet` crate
(`logos-blockchain/logos-execution-zone` at
`f7fda38a4428b9989f1db1dbf5d2411484848fd4`), needed so the Logos Kit wallet engine can embed
`wallet::WalletCore` in a Basecamp module and a CLI. Every patch keeps the existing CLI
behaviour and public API. The old entry points are now built from the new ones.

Apply:

```sh
git clone https://github.com/logos-blockchain/logos-execution-zone lez
cd lez && git checkout f7fda38a4428b9989f1db1dbf5d2411484848fd4
git am /path/to/logos-kit/vendor/lez-patches/*.patch
```

| # | File | Touches | +/- |
|---|------|---------|-----|
| 1 | `0001-storage-backend.patch` | `storage.rs`, `lib.rs` | +115 / -34 |
| 2 | `0002-sync-observer.patch` | new `sync_observer.rs`, `lib.rs` | +106 / -20 |
| 3 | `0003-public-tx-prepare-sign.patch` | `account_manager.rs`, `lib.rs` | +163 / -62 |
| 4 | `0004-private-tx-prepare-prove-submit.patch` | `lib.rs` | +105 / -23 |
| 5 | `0005-keycard-feature.patch` | `Cargo.toml`, `account_manager.rs`, `cli/mod.rs` | +20 / -4 |
| 6 | `0006-storage-remove-label.patch` | `storage.rs` | +5 / -0 |

Most of the lines in patches 3 and 4 are existing function bodies moved into the new
functions. The series adds no new dependencies.

## 1. `StorageBackend`: pluggable storage persistence

**Why:** `Storage` always writes plaintext JSON, and `WalletCore` writes it directly, including
once per synced block. With this patch we can encrypt the wallet at rest and debounce those
writes in our own backend.

```rust
// wallet::storage
pub trait StorageBackend: Send + Sync {
    fn load(&self) -> Result<Option<Vec<u8>>>;   // None = nothing stored yet
    fn save(&self, bytes: &[u8]) -> Result<()>;
}
pub struct FileBackend { /* path */ }            // default: the old plaintext file
impl FileBackend { pub const fn new(path: PathBuf) -> Self; pub fn path(&self) -> &Path; }
impl StorageBackend for FileBackend { .. }

impl Storage {
    pub fn to_bytes(&self) -> Result<Vec<u8>>;
    pub fn from_bytes(bytes: &[u8]) -> Result<Self>;
    pub fn load_from(backend: &dyn StorageBackend) -> Result<Self>;
    pub fn save_to(&self, backend: &dyn StorageBackend) -> Result<()>;
    // from_path / save_to_path are unchanged; they now go through FileBackend
}

// wallet::WalletCore
pub async fn new_with_storage_backend(
    config_path: PathBuf,
    storage_path: PathBuf,              // only used by storage_path() and in messages
    statistics_path: PathBuf,
    config_overrides: Option<WalletConfigOverrides>,
    storage: Storage,                   // Storage::load_from(&backend) or Storage::new(pw)
    storage_backend: Box<dyn StorageBackend>,
) -> Result<Self>;
pub fn set_storage_backend(&mut self, storage_backend: Box<dyn StorageBackend>);
```

All saves go through the configured backend, including `store_persistent_data` and the
per-block save during sync. The save cadence is unchanged. The on-disk format and the error
messages are also unchanged.

## 2. `SyncObserver`: sync progress without stdout

**Why:** sync used `println!` and an `indicatif` bar, so a UI had no way to show progress.

```rust
// wallet::sync_observer
pub trait SyncObserver: Send {                       // all methods default to no-op
    fn on_start(&mut self, blocks: RangeInclusive<BlockId>) {}
    fn on_block(&mut self, block_id: BlockId) {}      // block processed + storage persisted
    fn on_finish(&mut self, block_id: BlockId, elapsed: Duration) {}
    fn on_message(&mut self, message: &str) {}
}
#[derive(Default)] pub struct CliSyncObserver { .. }  // exact old output, keeps indicatif

// wallet::WalletCore
pub async fn sync_to_block_with_observer(&mut self, block_id: u64,
    observer: &mut dyn SyncObserver) -> Result<()>;
pub async fn sync_to_latest_block_with_observer(&mut self,
    observer: &mut dyn SyncObserver) -> Result<u64>;
// sync_to_block / sync_to_latest_block now call these with CliSyncObserver
```

The observer receives the old "Latest block is N" and per-block "Stored persistent accounts
at ..." lines as `on_message`.

## 3. Public tx: prepare, then sign and submit

**Why:** the user must approve the exact message before it is signed, and must be able to
drop it instead.

```rust
pub enum TxSigner {                                    // re-exported at crate root
    Local(AccountId),                                  // key looked up in storage at sign time
    Keycard { account_id: AccountId, key_path: String },
}
pub struct PreparedPublicTx { .. }                     // holds no private keys
impl PreparedPublicTx {
    pub const fn message(&self) -> &lee::public_transaction::Message; // incl. `.fee`, `.hash()`
    pub fn signers(&self) -> &[TxSigner];              // in signature order
}

// wallet::WalletCore
pub async fn prepare_public(&self, accounts: Vec<AccountMention>,
    instruction_data: InstructionData, program_account_id: AccountId,
    payer: Option<AccountId>,
    tx_pre_check: impl FnOnce(&[SelectedShard]) -> Result<(), ExecutionFailureKind>,
) -> Result<PreparedPublicTx, ExecutionFailureKind>;
pub async fn sign_and_submit_public(&self, prepared: PreparedPublicTx)
    -> Result<HashType, ExecutionFailureKind>;
// send_pub_tx_with_pre_check = prepare_public + sign_and_submit_public
```

The signature order is unchanged: local accounts, then keycard accounts, then an external fee
co-signer. For keycard signers, `PreparedPublicTx` holds the PIN that was read during
preparation (in a private field). `AccountManager` already did this. Signing moves from
`AccountManager::sign_message` to a crate-internal free `account_manager::sign_message`.

## 4. Private tx: prepare, prove, then sign and submit

**Why:** we need to run proving on our own worker thread, cancel it before anything is
submitted, and compare the proved public effects with what the user approved.

```rust
pub struct PreparedPrivateTx { .. }   // ProvingInput (holds private witnesses), program, signers
impl PreparedPrivateTx {
    /// CPU-heavy and blocking: run it on a worker thread.
    pub fn prove(self) -> Result<ProvedPrivateTx, ExecutionFailureKind>;
}
pub struct ProvedPrivateTx { .. }     // dropping it cancels the tx
impl ProvedPrivateTx {
    pub const fn message(&self) -> &privacy_preserving_transaction::message::Message;
    pub fn signers(&self) -> &[TxSigner];
}

// wallet::WalletCore
pub async fn prepare_private(&self, accounts: Vec<AccountMention>,
    instruction_data: InstructionData, program: &ProgramWithDependencies,
    tx_pre_check: impl FnOnce(&[SelectedShard]) -> Result<(), ExecutionFailureKind>,
) -> Result<PreparedPrivateTx, ExecutionFailureKind>;
pub async fn sign_and_submit_private(&self, proved: ProvedPrivateTx)
    -> Result<(HashType, Vec<SharedSecretKey>), ExecutionFailureKind>;
// send_privacy_preserving_tx_with_pre_check =
//   prepare_private + spawn_blocking(prove) + sign_and_submit_private
```

To cancel, drop the `ProvedPrivateTx`, or stop waiting for `prove`. A proof that is already
running still finishes on its thread, but nothing gets signed or submitted.

## 5. `keycard` Cargo feature (default on)

**Why:** `keycard_wallet` links PC/SC (`pcsc`), which we don't want in every module build.

```toml
[features]
default = ["keycard"]
keycard = ["dep:keycard_wallet"]
keycard-debug = ["keycard"]
```

Without the feature:

- The `wallet keycard ...` subcommand is not compiled.
- `m/...` key-path mentions and `TxSigner::Keycard` fail with "Keycard support is not enabled
  in this build".
- `pcsc` and `keycard-rs` drop out of the dependency tree.

`AccountIdentity::PublicKeycard` still exists, as plain data. Remaining gap: preparing a
`PublicKeycard` identity without the feature still prompts for a PIN before it fails at signing
time. Nothing in the CLI reaches that path, because key-path mentions fail earlier.

## Verification (at the tip of the series, macOS, toolchain 1.98.1)

Run with `RISC0_SKIP_BUILD_KERNELS=1 RISC0_SKIP_BUILD=1`, and `RISC0_DEV_MODE=1` for tests:

| Command | Result |
|---------|--------|
| `cargo check -p wallet` | Finished, exit 0 |
| `cargo check -p wallet --no-default-features` | Finished, exit 0 |
| `cargo clippy -p wallet --all-targets` | Finished, no warnings, exit 0 |
| `cargo clippy -p wallet --all-targets --no-default-features` | Finished, no warnings, exit 0 |
| `cargo clippy -p wallet --all-targets --features keycard-debug` | Finished, no warnings |
| `cargo test -p wallet --lib` | `test result: ok. 69 passed; 0 failed` |
| `cargo test -p wallet --lib --no-default-features` | `test result: ok. 69 passed; 0 failed` |
| `cargo check -p wallet-ffi` (downstream consumer) | Finished |

Clippy was clean after every individual patch. `git am` of the five files onto `f7fda38`
reproduces the branch exactly. Formatting uses stable `rustfmt`, because the repo's nightly-only
rustfmt options were unavailable.

## Upstream PR summary

> **wallet: make `WalletCore` embeddable (storage backend, sync observer, staged tx sending,
> optional keycard)**
>
> `WalletCore` is currently hard to embed outside the CLI:
>
> - It always writes plaintext JSON to disk.
> - Sync prints to stdout.
> - Building, proving, signing and submitting a transaction happen in one call.
> - It always links PC/SC.
>
> This series adds five small extension points:
>
> 1. A `StorageBackend` trait (`FileBackend` is the default), plus
>    `Storage::{to_bytes, from_bytes}`.
> 2. A `SyncObserver` for sync progress (`CliSyncObserver` is the default).
> 3. `prepare_public` / `sign_and_submit_public`, where `PreparedPublicTx` exposes the exact
>    `Message` and `TxSigner`s and holds no keys.
> 4. `prepare_private` / `PreparedPrivateTx::prove` / `sign_and_submit_private`, so proving can
>    run on a caller-chosen thread and can be cancelled before submission.
> 5. A default-on `keycard` feature.
>
> Each existing entry point is now a composition of the new ones. The CLI's output, on-disk
> format, signature ordering and errors are unchanged. There are no new dependencies. Clippy
> passes with the workspace lints, and all 69 wallet unit tests pass with and without default
> features.
