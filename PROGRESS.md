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

**Next action:** S0: when the inspector-enabled Basecamp build finishes, install the 3 `.lgx` into `--user-dir /tmp/lk-bc` with lgpm, run the identity-hop and sandbox probes (QML Inspector MCP), and record the results.

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
- [ ] Identity-hop probe: `requesterName` vs `current_caller()`. Record the result and the grant-key rule
- [ ] QML sandbox probes: Canvas paint, OS-opener path, bundled SVG, `textFormat`

### QA tooling
- [ ] Build `logos-qt-mcp`; run the design-system storybook

### Design and chain tooling
- [x] Brand assets: official marks and lockups from guide.logos.co → `assets/logos/logos/`, recorded in `docs/design/brand.md`
- [x] Drafts of `docs/design/parity-ledger.md` and `docs/design/ux-spec.md` (v0)
- [x] `xtask fingerprint`. Proof (2026-09-26): testnet reports `"version": "0.2.x"`, lastBlockId 25947, programs [amm, authenticated_transfer, pinata, privacy_preserving_circuit, token], `getFeeState` → -32601
- [ ] Background proving benchmarks E1–E4 and `RISC0_KECCAK_PO2`, recorded in `pins.md`

### Adoption
- [x] A-track drafts in `adoption/drafts/` (01 forum intro, 02 Discord, 03 signature-authorized private spends, 04 compact notes feed) plus `adoption/tracker.md`: **awaiting user approval to post**

### Exit criteria
- [x] `nix build ./modules/logos_kit_wallet#lgx-portable` succeeds on darwin-arm64. Proof: `EXIT 0`, `Added variant 'darwin-arm64' … logos-logos_kit_wallet-module-lib.lgx` (first build about 25 min). `logos_kit_wallet_ui` and `probe_dapp` lgx-portable builds also exit 0
- [ ] The module loads in Basecamp and answers `ping` via `logos.callModuleAsync`
- [ ] The probe results are recorded below
- [x] `pnpm i && pnpm check` is green
- [ ] `/code-review` run; findings recorded

### Decisions and deviations
- 2026-09-26: the brand is Logos Kit (D12). The repo-local git identity is `Blockchain-Oracle <blockchainoracle.dev@gmail.com>`.
- 2026-09-26: **pnpm 12.6 and TypeScript 7.0.2** (the latest majors, verified in Context7). pnpm 11+ settings live in `pnpm-workspace.yaml`, and `allowBuilds` replaces `onlyBuiltDependencies`. tsdown uses tsgo/oxc for `.d.ts`. The docs app may need TS 6 for twoslash; check in S8.
- 2026-09-26: `minimumReleaseAge` blocked `@types/node@26.6.3` (under 24h old), so the range was widened to `^26.0.0` rather than weakening the guard.
- 2026-09-26: Intent `params` types accepted by the shell are exactly `string | number | bool | object | array` (`IntentBroker.cpp:470-485`). Note it's **`bool`, not `boolean`**.

### Probe results
- **Headless core (logoscore 0.3.0, macOS arm64).**
  - Commands: `logosctl --config-dir <tmp> package install -y <lgx>` → `module load logos_kit_wallet` → `call logos_kit_wallet ping` / `whoami`.
  - Result: installed (unsigned, 0.1.0); loaded; `ping` → `{"module":"logos_kit_wallet","ok":true,"version":"0.1.0"}`; `whoami` → `{"kind":"host"}`.
  - Conclusion: `current_caller()` works through the scaffold. A CLI caller shows up as `host`.
- **Identity hop and QML sandbox:** waiting on the inspector-enabled Basecamp (`nix build .#bin-bundle-dir-inspector` in `refs/basecamp/logos-basecamp` @2c20227).

### Local tools installed (user-level, `~/.local/share/logos-tools/`)
- `lgpm` 0.2.1 (sha256 `56523ecb…d52cc`)
- `logosctl` / `logoscore` 0.3.0 (sha256 `a49f7a41…402d7`)
- Basecamp 0.3.0 release app in `~/Applications`
- building: `basecamp-inspector` (bin-bundle-dir-inspector) and `logos-qt-mcp`

### Review
(pending)
