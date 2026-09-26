# Logos Kit: progress

The single place to resume from after a context clear.

**Resume order:**
1. memory `MEMORY.md`
2. this file
3. `docs/dev/PLAN.md` (the current stage's section)
4. `docs/dev/pins.md`
5. the stage's "copy from" files

**Rules:**
- Tick an item only after its proving command passes, and paste the proof next to it.
- One branch per stage (`stage/NN-slug`).
- Nothing is pushed, published or deployed without the user's go-ahead.
- Tests are not a deliverable; only the integration-confidence tests listed in the plan.

**Next action:** S0 wrap-up: proving benchmarks E1–E4 + `RISC0_KECCAK_PO2` (pins.md), then `/code-review` for S0+S1-so-far. S1 continues on `stage/01-protocol`: LEZ fork patches, typify → `crates/lwsp-types`, Nix build of the engine.

---

## Stage S0 · Foundation, branch `stage/00-foundation`

**Status:** in progress (started 2026-09-26)

### Repo skeleton
- [x] Git repo, directory layout, `LICENSE-MIT`, `LICENSE-APACHE`
- [x] `docs/dev/PLAN.md` (copy of the approved plan), `docs/dev/pins.md`, `PROGRESS.md`
- [x] Memory pointer to `PLAN.md` / `PROGRESS.md`; the 0.3 date is labelled a target
- [x] `README.md`, `AGENTS.md`, `CONTRIBUTING.md`, `SECURITY.md`, `.gitignore`, `.editorconfig`

### Tooling
- [x] TS tooling: pnpm 12.6 (`packageManager`), catalog + `minimumReleaseAge 1440` + `allowBuilds`, Biome 2.5 (migrated to `preset`), TypeScript 7.0.2, changesets 3, `tsconfig.base.json` (`isolatedDeclarations`), `tsconfig.qml.json` (ES2017). Proof: `pnpm check` → "No fixes applied"; `pnpm check:repo` → "No issues found". (`knip.json` deferred until packages exist)
- [x] Rust workspace: `Cargo.toml` (resolver 3, `modules/` and `programs/` excluded), `rust-toolchain.toml` 1.98.1, `crates/xtask`. Proof: `cargo clippy -p xtask -- -D warnings` clean; `cargo fmt --check` ok
- [x] `justfile` with Nix on PATH (check, check-rust, fingerprint, lgx, lgx-dev, build-modules, basecamp-reset)
- [x] Logos AI skills copied into `.claude/skills/` and **git-ignored** (upstream has no licence)

### Modules and probes
- [x] `modules/logos_kit_wallet` (rust-module template; `ping`, `whoami`, `pinged` event). The `path:../..` pattern is deferred to S1 (external-staticlib pattern from widespread)
- [x] `modules/logos_kit_wallet_ui` (imports Logos.Theme/Controls, paints its own bg, provides `lez.wallet.connect`, answers with probe data). A dependency needs a flake input named like the dep (`logos_kit_wallet.url = "path:../logos_kit_wallet"`) because the builder reads its LIDL
- [x] `modules/probe_dapp` (throwaway; direct call, intent, sandbox probes)
- [x] Identity-hop probe: `requesterName` vs `current_caller()`. Result and grant-key rule under *Probe results*
- [x] QML sandbox probes: Canvas paint, OS-opener path, bundled SVG, `textFormat` (results below; screenshots in `docs/reviews/s0/`)

### QA tooling
- [x] Build `logos-qt-mcp` (`MCP EXIT 0`; driven from Node via `test-framework/framework.mjs` over TCP :3768)
- [ ] Run the design-system storybook (before S7)
- [x] Wallet design v2: `apps/design-lab` (React + 21st.dev/Motion Primitives/NumberFlow/Vaul components) with three working directions (Veil, Tray, Ledger); references study in `docs/design/references.md` + `docs/design/refs/`. Published for picks (artifact db collection `picks`).

### Design and chain tooling
- [x] Brand assets: official marks and lockups from guide.logos.co → `assets/logos/logos/`, recorded in `docs/design/brand.md`
- [x] Drafts of `docs/design/parity-ledger.md` and `docs/design/ux-spec.md` (v0)
- [x] `xtask fingerprint`. Proof (2026-09-26): testnet reports `"version": "0.2.x"`, lastBlockId 25947, programs [amm, authenticated_transfer, pinata, privacy_preserving_circuit, token], `getFeeState` → -32601
- [x] Proving benchmarks E1–E4 + `RISC0_KECCAK_PO2`, in `pins.md` ("Proving benchmarks"). M1 Pro 10-core/16 GB, CPU prover (risc0 3.0.5 has Metal commented out), load 8–58 so times are upper bounds. Fully private 469 s / 9.9 GB footprint; shield-like 337 s; 4 threads 692 s; 2 threads 1600 s; dev-mode executor 0.09 s. **KECCAK_PO2 does not cut memory** (worse at 14). **Segment po2 18: footprint 5.1 GB (from 9.9) for ~1.6× time**; po2 16 barely lower and 6.7× slower.

### Adoption
- [x] A-track drafts in `adoption/drafts/` (01 forum intro, 02 Discord, 03 signature-authorized private spends, 04 compact notes feed) plus `adoption/tracker.md`: **awaiting user approval to post**

### Exit criteria
- [x] `nix build ./modules/logos_kit_wallet#lgx-portable` succeeds on darwin-arm64. Proof: `EXIT 0`, `Added variant 'darwin-arm64' … logos-logos_kit_wallet-module-lib.lgx` (first build about 25 min). `logos_kit_wallet_ui` and `probe_dapp` lgx-portable builds also exit 0
- [x] The module loads in Basecamp and answers `ping` via `logos.callModuleAsync`. Proof: wallet UI shows `core: {"module":"logos_kit_wallet","ok":true,"version":"0.1.0"}` (`docs/reviews/s0/bc-wallet.png`)
- [x] The probe results are recorded below
- [x] `pnpm i && pnpm check` is green
- [ ] `/code-review` run; findings recorded

### Decisions and deviations
- 2026-09-26: the brand is Logos Kit (D12). The repo-local git identity is `Blockchain-Oracle <blockchainoracle.dev@gmail.com>`.
- 2026-09-26: **pnpm 12.6 and TypeScript 7.0.2** (the latest majors, verified in Context7). pnpm 11+ settings live in `pnpm-workspace.yaml`, and `allowBuilds` replaces `onlyBuiltDependencies`. tsdown uses tsgo/oxc for `.d.ts`. The docs app may need TS 6 for twoslash; check in S8.
- 2026-09-26: `minimumReleaseAge` blocked `@types/node@26.6.3` (under 24h old), so the range was widened to `^26.0.0` rather than weakening the guard.
- 2026-09-26: Proof UX numbers from the benchmarks: desktop ETA shield ≈5–6 min, fully private ≈6–8 min (elapsed timer + background proving; run the <0.1 s executor dry-run first to validate inputs and count cycles). Phones/paired provers: a LEZ patch **0006 (segment po2 via config)** is the memory lever; add it when S15 needs it. Real wallet txs pad inputs, so expect more cycles than the benchmark tests.
- 2026-09-26: **Design direction locked: Tray, light + dark (D14).** Tokens in `docs/design/brand.md`; reference implementation `apps/design-lab`. PLAN.md updated (rule 6, QML design system, S6 theme, S7 UI, S11 presets).
- 2026-09-26: Intent `params` types accepted by the shell are exactly `string | number | bool | object | array` (`IntentBroker.cpp:470-485`). Note it's **`bool`, not `boolean`**.

### Probe results
- **Headless core (logoscore 0.3.0, macOS arm64).**
  - Commands: `logosctl --config-dir <tmp> package install -y <lgx>` → `module load logos_kit_wallet` → `call logos_kit_wallet ping` / `whoami`.
  - Result: installed (unsigned, 0.1.0); loaded; `ping` → `{"module":"logos_kit_wallet","ok":true,"version":"0.1.0"}`; `whoami` → `{"kind":"host"}`.
  - Conclusion: `current_caller()` works through the scaffold. A CLI caller shows up as `host`.
- **Basecamp run (2026-09-26, inspector build `bin-bundle-dir-inspector` @2c20227, portable, macOS arm64).**
  - Install: `lgpm --modules-dir /tmp/lk-bc/modules --ui-plugins-dir /tmp/lk-bc/plugins --allow-unsigned install --file <lgx-portable>` ×3, then `LogosBasecamp --user-dir /tmp/lk-bc`. Both apps appear in the sidebar (user-installed modules **are** discovered by this build). Inspector port is up ~57 s after launch.
- **Identity hop.**
  - dApp → core directly: core sees `{"kind":"module","name":"probe_dapp"}`.
  - dApp → `lez.wallet.connect` intent → shell chooser ("Use this app?", provider listed by module id) → wallet UI gets `requesterName = "probe_dapp"`. When the wallet UI then calls the core, the core sees `{"kind":"module","name":"logos_kit_wallet_ui"}`.
  - After `respond`, the shell returns focus to the requester.
  - **Grant-key rule (S3):** `requester` = the module name. The shell's `requesterName` and `current_caller()` use the same namespace, so a grant made via an intent also matches that dApp's direct calls. The core can't see the original dApp on an intent hop; it trusts the `requester` only when relayed by `current_caller() == logos_kit_wallet_ui` (WalletUi). Any other module calling sensitive methods directly is `Module(name)` and needs a grant; `ui_*` methods are WalletUi-only.
- **Sandbox.**
  - `Qt.openUrlExternally("https://…")` → `false`; log: `Blocked URL import … scheme "https" is not allowed`. Links go through a core method (plan unchanged).
  - Bundled SVG (`qml/logo.svg`) → `Image.Ready`, renders.
  - **Canvas paints** in this build (green square visible). Deviation from the plan's caution: Canvas is allowed for QR/identicons on macOS; re-check on Linux in S7 before relying on it (Rectangle-grid fallback stays documented).
  - `textFormat: Text.PlainText` shows `<b>bold?</b>` literally. The rule stands.
  - `Logos.Theme/Controls/Icons` imports are redirected to the vetted design-system dir (log `Redirected Logos.Theme probe away from plugin tree`), confirming "import, never bundle".

### Local tools installed (user-level, `~/.local/share/logos-tools/`)
- `lgpm` 0.2.1 (sha256 `56523ecb…d52cc`)
- `logosctl` / `logoscore` 0.3.0 (sha256 `a49f7a41…402d7`)
- Basecamp 0.3.0 release app in `~/Applications`
- `basecamp-inspector` (bin-bundle-dir-inspector @2c20227) and `logos-qt-mcp`
- Apple Metal Toolchain 17F109 (`xcodebuild -downloadComponent MetalToolchain`; required by risc0-sys on macOS, per LEZ `flake.nix`)

### Review
(pending)

---

## Stage S1 · Protocol + engine links LEZ 0.3 + vectors, branch `stage/01-protocol`

**Status:** done (2026-09-26)

- [x] `@logos-kit/protocol` (LWS-0): TypeBox schemas → `schema/{lws0.schema.json,methods.json,intents.json}`; 12 methods, 6 notifications, 6 intents; `LezError` + codes. Proof: `publint --strict` and `attw --profile esm-only` pass; `dist/index.js` has no TypeBox import (`a97a3d1`)
- [x] `crates/wallet-engine` links `wallet`, `lee` (`prove`), `lee_core`, `key_protocol`, `common` at the pinned rev. Proof: `cargo test -p wallet-engine` builds with real Metal kernels, 5 tests pass (`aff4502`)
- [x] `cargo xtask vectors` → `protocol/vectors/{public_tx,keys}.json`: LEZ's 4 pinned message layouts, a signed native transfer (fixed aux rand, verified by LEZ's public verifier) incl. the `sendTransaction` base64 param and tx hash, public nodes `/`, `/0`, `/1`, `/0/0` (the wallet's layered order) and private nodes `/0`, `/1`
- [x] Integration test #1 (Rust side): `crates/wallet-engine/tests/vectors.rs` decodes the committed bytes with LEZ and re-verifies. Proof: `cargo test -p wallet-engine` → `vectors_*` 4 passed
- [ ] LEZ fork patches in `vendor/lez-patches/` (StorageBackend, SyncObserver, prepare/sign split, prove split, keycard feature)
- [x] typify → `crates/lwsp-types`: `cargo xtask types` (typify lib + pinned rustfmt). Emit now writes `$ref`s for named schemas (55), so types are named once (2.2k lines, was 7.6k). Proof: `cargo clippy -p lwsp-types -- -D warnings` clean (`17303d9`). CI diff lands with S9 workflows
- [x] Engine C ABI for the module: `lk_engine_info` / `lk_engine_call` / `lk_engine_free` (`include/wallet_engine.h`), JSON dispatch with `info` and `derivePublicAccounts`. Proof: exported symbols in `libwallet_engine.dylib`; dispatch test matches vectors (`b3e1ff8`)
- [x] Nix build of the module with the engine (macOS). Root `flake.nix` builds `wallet-engine` (crane, LEZ tarball + patches, circuits 2846ee7 ↔ v0.5.7, rapidsnark e91187f8, pre-fetched recursion zkr, Metal xcrun stub); the module takes it via `externalLibInputs` + CMake `EXTERNAL_LIBS` (a dylib, so the two Rust std copies never collide). Proof: `logosctl … call logos_kit_wallet engine_info` → `{"ok":true,"result":{"engine":"0.1.0","lezRev":"f7fda38a…"}}` (`ed0b5f6`). Lesson: without `EXTERNAL_LIBS` the plugin still links (dynamic lookup) and segfaults on the first engine call.
- [x] Same build on Linux (agari-box `nixos/nix` container, 4 GB/3 CPU): lgx `linux-amd64` with `logos_kit_wallet_plugin.so` + `libwallet_engine.so`. Proof (plain Debian, no Nix): plugin `NEEDED libwallet_engine.so`, `RPATH $ORIGIN`; engine exports `lk_engine_{info,call,free}`; ctypes call → `{"ok":true,"result":{"engine":"0.1.0","lezRev":"f7fda38a…"}}`. sha256 `6cc95e6a1fdc5344…`
- [x] LEZ patch series `vendor/lez-patches/0001–0005` (StorageBackend, SyncObserver, public prepare/sign, private prepare/prove/submit, keycard feature); verified in LEZ with check (default + no-default-features), clippy, 69 wallet tests (`b03bb7e`). Review note for S3: the keycard PIN is held in memory between prepare and sign. **Mechanism decided:** `vendor/lez/` = LEZ at the pinned rev + patches, generated by `cargo xtask lez-vendor`, and every LEZ crate comes from that path (never mixed git/path copies).

- [x] Linux builds (agari-box, `nixos/nix` container, 4 GB/3 CPU cap): all three modules `lgx-portable` for `linux-amd64` (variant name plain `linux-amd64`; plugin `logos_kit_wallet_plugin.so`). sha256 wallet `768a1a54…f0b2`, ui `f5c3f5a7…052a`, probe `f24b8590…7be2`. Note: UI flakes' `path:../logos_kit_wallet` needs a git checkout (a `git archive` copy fails in pure eval). Wallet cold build 420 s.
- [x] Code review (S0+S1) → 11 findings fixed in `4fa7cac` (QML gate `check:qml`, generated `provides`, vector coverage, rev/prefix self-checks, payload caps).

### Exit criteria
- [x] Module lgx with the engine builds and runs on darwin-arm64 and linux-amd64 (proofs above). **S1 complete (2026-09-26).**
- [x] `cargo test -p wallet-engine vectors` passes

### Decisions and deviations
- 2026-09-26: macOS builds of `lee/prove` need the Metal Toolchain (risc0-sys always compiles Metal kernels on macOS). Installed per LEZ's `flake.nix` note. `RISC0_SKIP_BUILD_KERNELS=1` is fine for `cargo check` only.
- 2026-09-26: vectors derive keys through LEZ's real `KeyTree` API, not our own path walk. The official wallet's layered order is `/0`, `/1`, `/0/0`, which a naive derivation would get wrong.
- 2026-09-26: the `keys.json` private entries embed LEZ's serde form of `KeyChain`, so the shape tracks upstream. Test mnemonic only (`abandon … about`), never funded.

---

## Stage S2 · Keystore, accounts, zones, sync, E2E harness, branch `stage/02-keystore`

**Status:** in progress (started 2026-09-26, while the S1 Linux build finishes)

- [x] `vault.v1` (`crates/wallet-engine/src/vault.rs`): Argon2id (64 MiB/t3/p1; bounds on load 19 MiB–1 GiB, t 2–10, p 1–8) → XChaCha20-Poly1305, header as AAD, lock file + staged 0600 + fsync + rename + dir fsync, `Zeroizing`. `EncryptedBackend` = LEZ `StorageBackend` (patch 0001) with debounced saves + flush. Proof: `tests/keystore.rs` 5 passed (round trip, wrong password, header tamper/bounds, crash mid-write, password change, debounce) (`87db62c`)
- [x] Session + zones (`session.rs`): `keys/` vault holds the phrase, `zones/<id>/` holds LEZ Storage per zone; offline-first (create/restore/unlock/accounts/new account without a sequencer; `connect()` builds `WalletCore`, stays offline and usable on failure). Proof: `tests/session.rs` 2 passed (`ec81a10`)
- [x] E2E harness `e2e/standalone.sh` (standalone `sequencer_service` from vendor/lez, `RISC0_DEV_MODE=1`, debug genesis, loopback :3040; needs `r0vm` 3.0.5 via rzup). `just e2e`. Fingerprint: version 0.3
- [x] Integration-confidence #2 (network half): `tests/e2e_sync.rs` creates public + private accounts, connects, syncs (observer `start 1..=3`, `finish 3`), sync position survives lock/unlock (`9653513`)
- [ ] Labels, import birthday, persisted indexes, auto-lock, mnemonic reveal with re-auth (engine API), network-drop backoff + offline banner state
- [x] Security review (S2 keystore): 12 findings, none critical. **Fixed:** one session per vault (exclusive `.session.lock`; blocks CLI/Basecamp lost updates and a password change being undone), pending saves kept until written + flush on drop + flush after a failed sync, all writes via random-name exclusive temp files (0600) + atomic rename, lock opened `O_NOFOLLOW`, data dirs 0700, zones/config written atomically, `Zeroizing` around serialized storage, `bip39`/`argon2` zeroize features, LEZ's plaintext `FileBackend` pointed at a never-read path, zone URL validated before any write + rollback of a failed create, KDF ceiling 256 MiB/t6/p4, phrase-taking FFI method test-only. Proof: engine tests 16 passed incl. 2 new regressions; E2E sync passes
- [ ] Security follow-ups (tracked): file role + zone id + write counter in the AAD (rollback / cross-zone swap), authenticate `zones.json` (keys vault or MAC), derive once per unlock (3 Argon2 runs today), zeroize-on-drop for LEZ `Storage` (LEZ patch), Windows owner-only ACL + exclusive lock
- [ ] Code review

### Exit criteria
- [x] Logos Kit creates accounts and syncs against the standalone sequencer (proof above)

### Decisions and deviations
- 2026-09-26: **Offline-first session.** `WalletCore::new` fails with "Failed to find leader" when no sequencer answers, so the session keeps LEZ `Storage` itself until `connect()`. Creating, restoring and unlocking a wallet never need the network.
- 2026-09-26: Keys and per-zone state are separate vaults under one password: adding a zone restores the same phrase, so accounts match across zones (LP-0022).
