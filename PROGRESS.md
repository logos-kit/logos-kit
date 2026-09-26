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

**Next action:** S0: write the root TS tooling (`package.json`, `pnpm-workspace.yaml`, `biome.json`, tsconfigs), checking changesets 3 and Biome 2.5 config in Context7 first.

---

## Stage S0 · Foundation, branch `stage/00-foundation`

**Status:** in progress (started 2026-09-26)

### Repo skeleton
- [x] Git repo, directory layout, `LICENSE-MIT`, `LICENSE-APACHE`
- [x] `docs/dev/PLAN.md` (copy of the approved plan), `docs/dev/pins.md`, `PROGRESS.md`
- [x] Memory pointer to `PLAN.md` / `PROGRESS.md`; the 0.3 date is labelled a target
- [ ] `README.md`, `AGENTS.md`, `CONTRIBUTING.md`, `SECURITY.md`, `.gitignore`, `.editorconfig`

### Tooling
- [ ] TS tooling: `package.json`, `pnpm-workspace.yaml` (catalog, `minimumReleaseAge`), `biome.json`, `tsconfig.base.json`, `tsconfig.qml.json`, `knip.json`, `.changeset/`
- [ ] Rust workspace: `Cargo.toml`, `rust-toolchain.toml` (1.98.1)
- [ ] `justfile` with Nix on PATH
- [ ] Copy the Logos AI skills into `.claude/skills/`

### Modules and probes
- [ ] `modules/logos_kit_wallet` skeleton (rust-module template, `path:../..` source)
- [ ] `modules/logos_kit_wallet_ui` skeleton (ui-qml template, 256 px icon, imports Logos.Theme/Controls/Icons)
- [ ] `modules/probe_dapp` (throwaway)
- [ ] Identity-hop probe: `requesterName` vs `current_caller()`. Record the result and the grant-key rule
- [ ] QML sandbox probes: Canvas paint, OS-opener path, bundled SVG, `textFormat`

### QA tooling
- [ ] Build `logos-qt-mcp`; run the design-system storybook

### Design and chain tooling
- [ ] Brand assets: official Logos SVGs, recorded in `docs/design/brand.md`
- [ ] Drafts of `docs/design/parity-ledger.md` and `docs/design/ux-spec.md`
- [ ] `xtask fingerprint` (tells 0.2.x from 0.3)
- [ ] Background proving benchmarks E1–E4 and `RISC0_KECCAK_PO2`, recorded in `pins.md`

### Adoption
- [ ] A-track drafts in `adoption/drafts/` (forum intro, Discord post, upstream proposals), for the user to approve

### Exit criteria
- [ ] `nix build ./modules/logos_kit_wallet#lgx-portable` succeeds on darwin-arm64
- [ ] The module loads in Basecamp and answers `ping` via `logos.callModuleAsync`
- [ ] The probe results are recorded below
- [ ] `pnpm i && pnpm check` is green
- [ ] `/code-review` run; findings recorded

### Decisions and deviations
- 2026-09-26: the brand is Logos Kit (D12). The repo-local git identity is `Blockchain-Oracle <blockchainoracle.dev@gmail.com>`.

### Probe results
(not run yet)

### Review
(pending)
