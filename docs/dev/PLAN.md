# LP-0021 Wallet + Connect Kit: Master Build Plan (staged, resumable)

## Context

We're building an entry for **Logos λPrize LP-0021 "LEZ Wallet and Provider SDK" ($20k)**. The prize requires:
- a wallet for the Logos Execution Zone (public + private accounts, token program, multiple accounts);
- a Wallet Provider SDK;
- testimonial + faucet mini-apps;
- a Basecamp (QML) GUI + CLI, published to a module catalog;
- E2E CI against a real standalone sequencer;
- adoption: 10 independent Basecamp apps, 150 on-chain testimonials over ≥2 months, 30 Discord + 30 X testimonials.

Around it we build the product: a wagmi/RainbowKit/Privy-grade connect kit for **React web and React Native/Expo**, with an embedded passkey wallet and Next.js docs. It is designed so the follow-ups extend it rather than rewrite it:
- **LP-0022** ($10k): L1 + staking + bridge + multi-zone, testnet 0.4.
- **LP-0001 rewrite** ($5k): NFT + private ownership proofs.

**Inputs.** Research and architecture are done:
- `docs/00`–`11`: architecture `docs/09`; decisions D1–D10 plus accepted review findings in `docs/10`; the Codex review in `docs/11`.
- 15 notes in `refs/connect-kits/_notes/`.
- About 100 cloned reference repos.

This plan went through four passes: exploration, two design agents, 21st.dev and Context7 research, and an adversarial audit (20 findings; 19 accepted, 1 rejected as wrong).

### Governing rules (memory `feedback-build-rules.md`, `feedback-research-depth.md`, doc 10)
1. **The LP-0021 checklist gates every stage.** Everything else is a bonus and never blocks it. All 3 surfaces are in scope (D1).
2. **Tests are not a deliverable.** Only the integration-confidence tests listed at the end. No UI tests.
3. **User flow is the product.** Loading, pending, empty, error and recovery states are first-class.
4. **UI comes from 21st.dev first:** the `21st` CLI plus the skills `21st-cli-use`, `21st-ui-build`, `21st-ui-explore`, `21st-ui-review`, `premium-ui`. We're on the paid tier (search + code, no AI generation).
   - The survey showed 21st's strength is **primitives**. The one "Connect Wallet Modal" (id 8588) ships placeholder logo SVGs.
   - So we **compose wallet screens from 21st primitives**, following RainbowKit, ConnectKit and Privy behaviour.
   - Verified: `21st add` uses shadcn, and shadcn auto-applies `components.json` `tailwind.prefix`.
5. **Real brand/token logos, never glyph icons.** Sources: `21st logo`/svgl plus the official Logos assets.
6. **Colours and design follow RainbowKit/wagmi**, not Logos' site. **Design direction locked 2026-09-26: Tray** (D14): Family-style content-height trays, keypad-first send, huge numerals, account chips, a background proof island, and **both a light and a dark set**. RainbowKit colour roles: `private` #7A70FF (only ever means private), `action` #3898FF. Reference implementation: `apps/design-lab` (`src/lab/tokens.ts` → `trayLight` / `trayDark`, `Wallet.tsx`, `Sheet.tsx`); rationale and sources in `docs/design/brand.md` and `docs/design/references.md`.
7. **Docs: Next.js via Fumadocs 16 + Next 16**, with product fidelity against the wagmi, RainbowKit and Privy docs.
8. **Libraries freely, but Context7 first.** Firecrawl for anything current. Install tools via their official methods.
9. **Never self-block.** Escalate only for access (see Inputs).
10. **Everything is clean, importable and publishable.** Nothing is pushed or published without the user's go-ahead.

---

## Reference contract and parity ledger (product fidelity)

The references are a **minimum baseline**. Allowed deviations: brand, the LEZ protocol, privacy features, and additive features.

| Reference | Pinned | Authoritative for |
|---|---|---|
| RainbowKit | `refs/connect-kits/evm/rainbowkit` | Modal flows, wallet list, theming API, ConnectButton + `.Custom`, account/chain modals, recent tx, i18n |
| ConnectKit | `refs/connect-kits/evm/connectkit` | Connection states, height morph, shake, 45 s expiry countdown |
| wagmi/viem | `refs/connect-kits/evm/{wagmi,viem}` | Layering, errors, packaging, SSR/hydration, docs IA and per-hook template |
| Privy (docs + examples) | `refs/connect-kits/embedded/*`, notes 07 | Create-on-connect, confirmation sheet + `uiOptions`, export, account centre, step-up |
| Porto | `refs/connect-kits/passkeys/porto` | Passkey dialog/popup isolation, messenger |
| Logos EVM signer stack | `refs/wallet-refs/logos-evm-*` | Approval protocol: requester / approver / keystore roles, password per approval, echoed bundle id. **Pattern only (no licence)** |

**`logos-kit/docs/design/parity-ledger.md`** is written in S0 and updated in every UI stage. Each reference capability gets one status:
- **Exact**
- **Adapted**
- **Additive**
- **Blocked**, with the reason

Nothing is silently dropped. The ledger explicitly lists:
- connect modal states
- wallet list: recent / detected / recommended
- account modal and network/zone modal
- sign-in (`lez_signIn` / `useSignIn`)
- capabilities (`useCapabilities`)
- recent-transactions store
- i18n with lazy locales
- SSR (cookie storage + hydration)
- a11y (focus trap, aria, ESC, `prefers-reduced-motion`)
- Wallet Standard self-registration
- 45 s intent timeout, plus the "request already open" busy guard
- Privy `uiOptions`, account centre, step-up
- testimonial client on all three surfaces (D2)

**`logos-kit/docs/design/ux-spec.md`** is written before any UI stage. It covers every flow, state and piece of copy. QML, React and RN all implement the same spec.

---

## Where the code lives, and naming

- **Main repo:** `/Users/abu/dev/hackathon/logo-tech/logos-kit/` (new git repo). `docs/` and `refs/` stay outside it as the research workspace.
- **Catalog repo:** a separate fork of **`logos-modules-release-base`** (e.g. `logos-kit-modules`).
  - LP-0021 line 41 literally requires "a fork of logos-modules-release-base".
  - The wallet repo's module directories are added as submodules via `scripts/add-module.sh` with `module_path: submodules/<repo>/<module-dir>`. `release.yml:175-183` supports multi-module repos.
  - Its raw `logos-repo.json` is the URL we submit.
- **Brand: Logos Kit** (chosen 2026-09-26). Availability checked the same day:
  - GitHub `logos-kit` org/user name: free.
  - npm `@logos-kit/*` scope and `create-logos-kit`: free.
  - The unscoped npm name `logos-kit` belongs to an unrelated package, so we always publish scoped.
- **Names:**
  - npm `@logos-kit/*`
  - Basecamp modules `logos_kit_wallet`, `logos_kit_wallet_ui`, `logos_kit_testimonial`, `logos_kit_faucet`, `logos_kit_wallet_fake`
  - CLI `logos-kit`
  - repo `logos-kit`, catalog fork `logos-kit-modules`
  - testimonial submission id `LP-0021/logos-kit`
  - suggested testimonial text: "I use Logos Kit wallet …"
  - QML singleton `LogosKit`
- **Never use official module names:** `lez_core`, `lez_wallet_ui`, `lez_faucet`, `lez_faucet_ui`.
- **Our own data dir** (e.g. `~/.local/share/logos-kit/`), never `~/.lee/wallet`. It has an **advisory file lock**, because the CLI and the Basecamp module share it.

### Repo layout (`logos-kit/`)
```
PROGRESS.md  README.md  AGENTS.md  LICENSE-MIT  LICENSE-APACHE  CONTRIBUTING.md  SECURITY.md
docs/dev/{PLAN.md (copy of this plan), pins.md}   docs/design/{parity-ledger.md, ux-spec.md, brand.md}   docs/reviews/
adoption/{tracker.md, snapshots/}                  demo.sh
justfile   flake.nix (root devShell + lgx aliases, lez-programs/flake.nix pattern)
Cargo.toml Cargo.lock rust-toolchain.toml(1.98.1)          # Rust workspace; guests excluded
package.json pnpm-workspace.yaml biome.json tsconfig.base.json tsconfig.qml.json knip.json vitest.config.ts .changeset/
protocol/      @logos-kit/protocol — src/schema/*.ts (TypeBox 1.x `typebox`, BUILD-TIME ONLY) → schema/{lws0.schema.json, methods.json, intents.json} (canonical, committed), fixtures/, vectors/ (generated by Rust)
crates/        lwsp-types (typify, CI diff) · wallet-engine · logos-kit-cli · xtask
vendor/lez-patches/
modules/       logos_kit_wallet (core, Rust cdylib shim) · logos_kit_wallet_ui · logos_kit_testimonial · logos_kit_faucet · logos_kit_wallet_fake   (one flake.nix each)
programs/testimonial/{core, methods/guest, build/}
registry/programs.json      # metadata (claims, never proof)
sdk/qml/LogosKit/          # qmldir + LogosKit.qml + logoskit.js (generated from TS, checked in)
templates/basecamp-dapp/
packages/      codec keys client core react theme react-ui embedded react-native expo-plugin(tsc→CJS) test qml-bundle(private) create-app   (tsdown ESM-only, `exports: true` auto-generated)
apps/          docs wallet playground expo-example cors-proxy
e2e/           standalone scripts + e2e/rust
.github/workflows/
```

**Boundary rules**
- Nix builds never need node: `logoskit.js` is checked in, and CI fails on a diff.
- The JSON Schema is canonical. TypeBox is used only at authoring time and never ships in the QML bundle.
- Vectors flow Rust → TS.
- QML-safe packages (`protocol`, the `codec` root, `client`, `core`, `theme`) must not use:
  - native BigInt (u64/u128 travel as decimal strings; bn.js internally)
  - regex named groups, lookbehind or the `s` flag
  - core-js or `Intl`
  - uninitialised class fields

  Enforced by `tsconfig.qml.json`, Biome and the runtime QML gate.

### Reuse (licences verified 2026-09-26)
- **Code reuse allowed:**
  - `refs/wallet-refs/logos-accounts-ui/rust-core/src/vault.rs` (**MIT OR Apache-2.0**; LICENSE files present)
  - `refs/lez/lez-programs/apps/shared/wallet/` (MIT): `TransactionConfirmationDialog`, `ProgramAccountSelector`
  - `refs/lez/lez-faucet` (MIT + Apache): the outcome-unknown state machine in `lez-faucet-ffi/src/client.rs`, and its workflows
  - `refs/lez/logos-execution-zone-wallet-ui` (MIT + Apache)
  - wagmi, RainbowKit, Porto, ox, wallet-adapter
- **Pattern only:** the EVM signer stack (no licence), AppKit/WalletConnect (Reown licence), Daimo (GPL).

### Library versions (npm, 2026-09-26; pinned via pnpm `catalog:` and recorded in `pins.md`; every API checked in Context7 at first use)
| Library | Version |
|---|---|
| next | 16.3 |
| react | 19.3 |
| react-native | 0.87 |
| expo | 57 |
| react-native-passkeys | 0.4.2 (PRF, peer expo ≥53) |
| fumadocs-core / ui | 16.15 |
| fumadocs-mdx | 15.4 |
| fumadocs-twoslash | 4 |
| fumadocs-typescript | 5 |
| tsdown | 0.23 |
| @changesets/cli | 3 |
| @biomejs/biome | 2.5 |
| vitest | 5 |
| zustand | 5 |
| @tanstack/react-query | 5.104 |
| @noble/curves, @noble/hashes | 2.4 |
| @noble/post-quantum | 0.7 |
| ox | 1.8 |
| typebox | 1.3 |
| @wallet-standard/app | 1.1 |
| tailwindcss | 4.3 |

**Copy structure from wagmi, not its old versions** (wagmi still uses changesets 2 and vitest 4).

---

## Handoff convention (resume after any context clear)

1. **`logos-kit/PROGRESS.md`** has one block per stage:
   - checkbox items naming file paths
   - `Exit criteria`, each with its proving command
   - a dated `Decisions/deviations` log with evidence
   - `Review` results
   - a one-line `Next action`

   Tick an item only after its proving command passes, and paste the proof next to it.
2. **`docs/dev/PLAN.md`** is a copy of this plan, kept in sync. **`docs/dev/pins.md`** records every pin.
3. **Memory:** in S0, add a pointer to `logos-kit/docs/dev/PLAN.md` + `PROGRESS.md` in `lp0021-project.md`, and relabel the 0.3 date as a *target*. Update memory at each stage exit.
4. **Git:** one branch per stage (`stage/NN-slug`), small commits, `main` green before moving on. Push, PR, publish and deploy only after the user's go-ahead (see Inputs).
5. **Cold resume order:**
   1. memory `MEMORY.md`
   2. `logos-kit/PROGRESS.md`
   3. `docs/dev/PLAN.md`, at the current stage
   4. `pins.md`
   5. the stage's "copy from" files
6. **Every stage:** Context7 before any new library, Firecrawl for anything current, `reference-product-fidelity` on UI/docs stages. Independent sub-tasks can fan out to subagents.
7. **Decision log:** any decision change goes into `docs/10-decisions-and-ecosystem.md`. For example, **D11:** the docs framework is Fumadocs on Next.js, not Vocs (user rule), so Rust twoslash is lost.

## Review gates

- **Every stage exit:** `/code-review high` → fix → record in PROGRESS.
- **Also `security-review`** at S2 (keystore), S3 (policy/approvals), S7 (module shim), S12 (embedded wallet) and S15 (pairing/prover).
- **UI stages** (S7, S8, S11–S14): `21st-ui-review` plus a parity-ledger check at desktop and mobile widths.
- **Usability sessions:** 2–3 non-expert users try the Basecamp flows at S8, and again before submission. Findings go to PROGRESS.
- **Milestone Codex reviews:** at S8 and S18, using a fresh prompt in `docs/reviews/`, modelled on `docs/CODEX-REVIEW-PROMPT.md`.

---

## Performance design (built in, not bolted on)

**Engine (Rust)**
- Sync runs on a background tokio task. `getBlockRange` is batched.
- Private notes are view-tag prefiltered, then decrypted in parallel (rayon, bounded).
- Persistence is debounced.
- Polling uses backoff with jitter. Status is coalesced by handle, and account state is cached per zone.
- Proving runs on a dedicated thread pool with capped `RAYON_NUM_THREADS`, so the UI and sync stay responsive. `RISC0_KECCAK_PO2` is tuned from the S0 benchmarks.

**QML**
- Every module call is `callModuleAsync`; nothing sync on the UI thread.
- ListView uses light models and a paginated activity list. No large `JSON.parse` per frame.
- Hidden views pause their pollers.
- If activity lists get large, switch that view to the `ui-qml-backend` C++ model (`logos.model()`; doc 03 §1.4).

**Web**
- Core under 30 kB gzip (size-limit).
- Lazily loaded: the modal, QR, locales, logos and the "all wallets" view.
- `useSyncExternalStore` with selectors; TanStack dedupe and cache.
- Private scanning in a Web Worker.
- Preconnect to and prewarm the wallet-origin iframe.
- Fumadocs builds statically, with Orama static search.

**React Native**
- Only light JS on the UI thread.
- `@noble` signing (tens of ms) is fine. ML-KEM scanning runs in the background and gets measured on Hermes; UniFFI is the fallback.

**Budgets (measured and recorded in S9/S16)**
- Basecamp launch
- Approval-sheet paint under 100 ms
- Account switch
- Sync catch-up
- Proving time for shield and private send
- Web time to interactive for the modal

---

## Basecamp / QML architecture (applies to S0, S7, S8 and the fake wallet)

**Verified sandbox facts** (`refs/basecamp/logos-basecamp/app/restricted/`, `docs/app-to-app-intents.md`, and the QML tooling research). These shape the design.

**Network, links and assets**
- The network is deny-all. The only URLs allowed are `qrc:` and files inside our own module directory.
- **`Qt.openUrlExternally(https://…)` is blocked.** Explorer and docs links are rendered as copyable text, plus an "Open" button that calls a Rust-core method which launches the OS opener (verified in S0).
- **Remote images and `data:` URIs are blocked.** Token logos, brand logos and chain logos are **bundled SVGs** in the module directory (qtsvg ships with Basecamp), resolved from a bundled registry map with an identicon fallback.
- A **Canvas may never paint** inside the plugin widget. So:
  - identicons are built as a Rectangle grid;
  - QR codes use `qrcodegen.js` (Nayuki, MIT, copied from `refs/wallet-refs/logos-eth-wallet-ui/src/qml/qrcodegen.js` plus `EthWalletView.qml:649-675`), drawn as Rectangle runs;
  - S0 still tests Canvas early.

**Storage and naming**
- There's **no per-app storage.** UI preferences live in the Rust core (`module_data/<module>/`), read via `callModuleAsync`. `QtCore.Settings` is shared host-wide, so we avoid it.
- **Unique qmldir namespaces** (`LogosKitWallet`, `LogosKitShared`) prevent type collisions with other plugins. Shared QML libraries have their `plugin`/`prefer` lines stripped (`refs/lez/lez-programs/apps/amm/flake.nix:46-66`).

**Rendering**
- **Every untrusted string** (requesterName, package metadata, memos, testimonial text, token names) is rendered with `textFormat: Text.PlainText`, because `LogosText` auto-detects rich text. This is a security rule.
- **Always paint our own background** (`Rectangle { color: Tokens.background }`); the host widget behind it is white.
- **Readiness:** seed `ready` in `Component.onCompleted`, then update it from `onViewModuleReadyChanged`. A binding on `isViewModuleReady()` never updates.

**Intents**
- **Payload rules:** plain data only; ≤8 levels deep; ≤1000 nodes; strings ≤64 KB; integers ≤2^53. Amounts are decimal strings, and large transaction proposals are passed by reference (a handle), not inline.
- **`provides[].params` is enforced by the shell** before our handler runs. `uses` entries **must be objects**; a bare string array silently fails. The dApp template and conformance kit both guard against this.
- **Shell behaviour:** one dialog at a time; it auto-returns the user to the requester after we answer. `handoff: true` goes only on `lez.wallet.open`. The 10-minute backstop means we answer at *acceptance* for long work, as §3.1 already says.
- **No well-known intent registry exists yet** (doc §7). We publish our `lez.*` intent spec (names, param and result schemas, semantics) in the docs and propose it upstream. That's an ecosystem contribution and an adoption lever.

**Design system**
- `Logos.Theme` is **dark-only, with a read-only palette.**
- Designed controls: Button, Checkbox, ComboBox, IconButton, Paginator, SearchBar, TabBar, Table, Text, TextField.
- Available but less polished: Dialog, Drawer, Toast, Badge, CopyButton, CopyableText, Notice, StatCard, Tile, Spinner, ProgressBar, ToolTip.
- Icons are generic only; there are no wallet icons.
- We build our own **`Tokens.qml` singleton** generated from `@logos-kit/theme`'s **Tray** tokens (D14). Our views paint Tray surfaces, text, radii (tray 36, card 26, pill buttons, rows 20) and the Onest font (bundled, loaded with `FontLoader`) themselves, so the wallet looks the same in Basecamp, on the web and on phones. **Basecamp opens in Tray dark** (the shell is dark-only); a light/dark switch in Settings is stored by the core module. `Logos.Theme`/`Logos.Controls` are still imported (never bundled) and used only for behaviour the shell expects (focus, text input), restyled to our tokens.
- **Tray patterns in QML:** content-height trays = `Behavior on height` over the measured `implicitHeight` (200 ms, `Easing.Bezier` .25,.1,.25,1) with step swaps that scale 1.08 → 1 forward and reverse on back; ✕ becomes ← after step 1; the proof island = a pill with a spring `Behavior on width` pinned to the top of the view; keypad send with per-digit enter animations; account chips in a horizontal `ListView`; balance numerals with tabular figures and the unit in `text2`.

### QML module structure (each ui module)
```
modules/logos_kit_wallet_ui/
  metadata.json   (type ui_qml, view qml/Main.qml, dependencies:[logos_kit_wallet], provides[{intent, params, handoff?, web?}])
  flake.nix (mkLogosQmlModule)   icons/icon.png (256px)   assets/logos/*.svg (bundled brand + token logos)
  qml/Main.qml                 // paints bg, owns Store, switches pages by `visible`, hosts the Sheet layer
  qml/LogosKitWallet/qmldir    // unique namespace
    Store.qml                  // THE ONLY file that touches `logos`: call()/parse() around callModuleAsync (+timeout), onModuleEvent, intent Connections
    Tokens.qml (singleton)     // Theme.palette + our accent/status + breakpoints (compact < 680px, phone ≈ 360px)
    Flow.js (.pragma library)  // pure logic: amount formatting (strings), error-code → copy mapping, state machines
    logoskit.js                // the transpiled TS protocol/state layer (S6), shared with dApps
    atoms/   AddressText, Identicon (Rectangle grid), QrCode (qrcodegen.js), TokenLogo, AmountField, StatusPill, KindBadge, CopyRow
    sheets/  Sheet.qml (from accounts-ui), ConnectSheet, ApprovalSheet, UnlockSheet
    pages/   Onboarding, Accounts, Home, Send, Receive, Activity, Grants, Settings
```
- **Copy from:**
  - `refs/wallet-refs/logos-accounts-ui/src/qml/AccountLog/{Store,Sheet}.qml` (the best component discipline; MIT/Apache)
  - `refs/wallet-refs/logos-evm-signer-ui/qml/SignerView.qml:44-95` (intent-provider pattern) and its `docs/specs.md` (approver UI rules)
  - `refs/lez/lez-programs/apps/shared/wallet/qml/{TransactionConfirmationDialog,WalletControl}.qml` (responsive sheets, `compactLayout`)
  - `refs/competitors/persona/ui/Main.qml:90-120` (`call`/`parse` around `callModuleAsync`, which returns a JSON string)
  - `refs/lez/lez-faucet/faucet-ui/src/qml/FaucetFlow.js` (pure-function style, u128 values as strings)
- **State pattern:** one Store QtObject per app, with read-only parsed properties and `ready`/`busy`/`error` per call. Views take props and emit signals. Sheets stay open until the backend answers and show errors inline.
- **Responsive:** design at about 360 / 680 / 1024 px from day one, using the `compactLayout` rule. Mobile Basecamp (Qt 6.11) is QML-only, so this is our phone path.

### QML dev loop and QA tooling
1. **Design-system storybook** (`nix run` in `refs/basecamp/logos-design-system`) to check tokens and controls.
2. **Fast layout iteration:** `nix build .#ui-dev`, then `./result/bin/run-logos-standalone-ui`. It hot-reloads in about 200 ms via `DEV_QML_PATH`, but has no intents and no sandbox, so it's for layout work only.
3. **Core module API:** tested headless through `logoscore-py` (`LogoscoreDaemon(modules_dir)` → `call` / `on_event`) against the real module. This runs alongside the Rust e2e.
4. **Full Basecamp with intents and the sandbox:**
   - an isolated instance: `LogosBasecamp --user-dir /tmp/lk-bc`;
   - the reset procedure from `logos-module-build-loop`: `pkill -9 -f 'logos_host|logos-basecamp|\.logos_host\.elf'; rm -rf <userdir>/{modules,plugins}/logos_kit_*`, then install the fresh `.lgx`;
   - `tail -F <session>/logs/basecamp.log` (`console.log` output and `lcBasecampSandbox` warnings).
5. **Visual QA with the QML Inspector MCP** (`logos-qt-mcp`, port 3768; `nix build .#logos-qt-mcp`):
   - `qml_screenshot`, `qml_find_and_click`, `qml_list_interactive`;
   - resize via `qml_set_property` to 360 / 680 / 1024;
   - key items get `objectName`s.

   The agent uses this to walk every state in `ux-spec.md`. That walkthrough is **QA, not a test suite.**
6. **One integration flow script** (`tests/intent-flow.mjs`, qt-mcp framework, pattern from `refs/lez/lez-programs/apps/amm/tests/swap.mjs` and `refs/wallet-refs/logos-evm-signer-ui/doctests/`): dApp → `lez.wallet.connect` → chooser → ConnectSheet → approve → `lez.transaction.send` → ApprovalSheet → handle → status. This is the prize's core flow, so it counts as an integration-confidence test.
7. **Agent guidance:** copy `refs/tooling/logos-ai-skills/skills/{logos-ui-qml-builder,logos-core-module-builder,logos-module-build-loop,logos-discovery}` into the repo's `.claude/skills/` in S0.
8. **Known gotchas** (from those skills):
   - the variant may be named `linux-amd64-dev` where `linux-amd64` is expected;
   - the plugin may be built as `<name>_plugin.so` where Basecamp expects `<name>.so`;
   - some public Basecamp releases didn't discover user modules, so we pin a Basecamp version in `pins.md`;
   - chain cleanup commands with `;`, not `&&`.

---

## Timeline (targets; today Sat 2026-09-26; 0.3 launch **target** 2026-09-30)

| Stage | Target dates |
|---|---|
| S0 | Sep 27–28 |
| S1 | Sep 29–Oct 1 (S5 guest runs in parallel from here) |
| S2 | Oct 2–3 |
| S3 | Oct 4–7 |
| S4 + S6 | Oct 8–10 |
| S7 | Oct 11–15 |
| **S8 first release, adoption clock starts** | **about Oct 20** |
| S9 | Oct 20–24 |

The strict reading of the adoption window is calendar months, ≥30 in each, over ≥2 months. That makes Nov and Dec the qualifying months, and **S18 submission about early Jan 2027**. The kit track (S10–S16) runs Oct 20 → Dec, during the adoption window. S17 starts when testnet 0.4 exists.

---

## Stages

- **Prize path:** S0–S9 (first release at S8)
- **A-track:** adoption, from S0 to submission
- **Kit track:** S10–S16
- **S17:** LP-0022
- **S18:** submission

### S0 · Foundation
- **Repo skeleton:** `git init`, licences, CONTRIBUTING, SECURITY, `PROGRESS.md`, `docs/dev/{PLAN.md,pins.md}`, and the memory pointer.
- **Tooling:** pnpm 10 + `catalog:` + `minimumReleaseAge 1440`, Biome 2.5, sherif, knip, changesets 3. Structure copied from `refs/connect-kits/evm/wagmi/{package.json,pnpm-workspace.yaml,biome.json,tsconfig.base.json,.changeset/}`, versions current.
- **Rust workspace** on 1.98.1.
- **Module skeletons:**
  - `logos_kit_wallet` from `refs/basecamp/logos-module-builder/templates/rust-module/`, with a `path:../..` source input as in `refs/competitors/widespread-logos/modules/widespread_wallet/flake.nix`.
  - `logos_kit_wallet_ui` from `templates/ui-qml/`, with a 256 px icon. It **imports** `Logos.Theme`/`Controls`/`Icons` and never bundles them.
  - `probe_dapp` (a throwaway ui_qml) for the identity probe.
- **QML sandbox probes** (in the probe dApp): Canvas paint, the OS-opener path for links, bundled SVG rendering, and `textFormat` behaviour. Results go to PROGRESS and the QML section is adjusted if needed.
- **Agent guidance:** copy the Logos AI skills into `.claude/skills/`. Build `logos-qt-mcp` and the design-system storybook, and pin the Basecamp version in `pins.md`.
- **Identity-hop probe** (moved here because S3's grant keys depend on it). `probe_dapp` raises an intent to `logos_kit_wallet_ui` and also calls `logos_kit_wallet` directly. Log whether `requesterName` equals the dApp's `current_caller()` name. Record the result and the resulting grant-key rule in PROGRESS.
- **Nix on PATH:** `/nix/var/nix/profiles/default/bin`.
- **Linux builds:** via CI (after the user's go-ahead), or agari-box as a Nix remote builder.
- **Clean-machine testing:** macOS and Linux VMs via UTM/tart. Basecamp needs a GUI, so a headless server won't do.
- **Brand assets:** official Logos SVGs (logos.co brand page via Firecrawl) → `docs/design/brand.md` + `assets/`.
- **Design docs:** drafts of `parity-ledger.md` and `ux-spec.md`.
- **`xtask fingerprint`:** distinguishes 0.2.x from 0.3 using `getFeeState` / `getProgramIds`. Pattern: `refs/lez/lez-faucet/.github/workflows/testnet-fingerprint.yml`.
- **Background benchmarks:** E1–E4 plus the `RISC0_KECCAK_PO2` test (`refs/connect-kits/_notes/08` §c, `13`). Results go into `pins.md`.
- **A-track kickoff:** see the A-track section.
- **Exit:**
  - `nix build ./modules/logos_kit_wallet#lgx-portable` succeeds (darwin-arm64);
  - the module loads in Basecamp and answers `ping`;
  - the probe result is recorded;
  - `pnpm i && pnpm check` is green.

### S1 · Protocol + engine links LEZ 0.3 + vectors
- **`@logos-kit/protocol` (LWS-0).** Start from note 04 §8 and apply the doc 09 corrections:
  - `programId` = the header account;
  - `lifecycle` and `outcome` are separate fields;
  - CAIP-2 zones with the sequencer as data;
  - the namespace can grow from `lez_*` to `l1_*`.
- **New in LWS-0:**
  - **Capability-scoped grants.** A proof request is separate from account access; this is the LP-0001 hook.
  - `lez_requestFunds`, the in-flow faucet from the Discord request.
  - `lez_signIn`, `lez_getCapabilities`.
  - **Per-origin opaque private-account handles** (LWS-0 §8.4 rule 4).
  - Gas fields `estimatedFee` and `gasUsed | unavailable`.
- **Errors:** viem-style `BaseError` plus coded classes: 4001, 4100, 4200, 4900, 4901, 57xx, 6100–6106 (6106 = `StaleApproval`).
- **LEZ fork patches** (`vendor/lez-patches/`, via `[patch]`, each under ~100 lines and also sent upstream as a PR):
  1. `StorageBackend` + `Storage::{to_bytes,from_bytes}`
  2. `SyncObserver` replacing indicatif and `println!`
  3. `prepare_public` / `sign_and_submit_public`
  4. `prove_private` / `sign_and_submit_private`
  5. `keycard_wallet` behind a default-on feature

  A wrapper can't do this, because `storage.rs:76-84` writes plaintext and `lib.rs:1051` saves on every block.
- **Build setup:** enable `lee/prove`. Take the Nix env from the widespread flake: `LBC_ROOT_DIR`, `RAPIDSNARK_LIB_DIR`, artifacts.
- **Target 0.3 only.** Use the standalone sequencer at the rc pin until launch, then re-pin to the final `v0.3.0` tag. No v0.2 codec.
- **`cargo xtask vectors`** → `protocol/vectors/{public_tx,keys}.json`. Sources:
  - `lee/state_machine/src/public_transaction/message.rs` tests
  - `lee/key_protocol/src/key_management/key_tree/{keys_public.rs:111-160,keys_private.rs}`
- **typify** → `crates/lwsp-types`.
- **Exit:** `nix build .#logos_kit_wallet-lgx` succeeds on darwin-arm64 (plus Linux via CI or the remote builder), and `cargo test -p wallet-engine vectors` passes.
- **Timebox:** 2 days on the Nix build. Fallback: C++ over `wallet-ffi` plus a Rust sidecar (the `refs/lez/logos-execution-zone-module` pattern).

### S2 · Keystore, accounts, zones, sync, E2E harness
- **Keystore:** adapt `logos-accounts-ui` `vault.rs`.
  - `vault.v1`: Argon2id → XChaCha20-Poly1305.
  - Atomic writes: temp file → fsync → rename → dir fsync, mode 0600.
  - Advisory file lock.
  - Debounced saves.
  - Auto-lock, password change, and mnemonic reveal (requires re-auth).
- **Zones:** `config.json` holds the zone list; all state is keyed per zone. This is the LP-0022 hook.
- **Accounts:** public and private, labels, import (including a mnemonic from the official wallet), birthday, persisted indexes.
- **`SyncEngine`:**
  - tip-first, cancellable, per-zone checkpoints, progress events, network-drop backoff, offline state;
  - **block source:** the sequencer `getBlockRange` (trust = the user's configured sequencer); later, an optional indexer feed from the user's own node.
- **E2E harness:** `e2e/standalone.sh` runs `sequencer_service --features standalone` at the pinned rev (port 3040) with `RISC0_DEV_MODE=1`. That flag disables proof verification, per `Justfile:123` and LEZ `ci.yml:213,255,304,376`. Also:
  - r0vm via `rzup`
  - genesis accounts imported
  - recipe: `refs/competitors/widespread-logos/.github/workflows/ci.yml` (`e2e-standalone`)
- **Confidence test:** `e2e/rust/tests/keystore_restore.rs` covers crash mid-write, disk full, wrong password, network-drop then resync.
- **Review:** code-review + security-review.
- **Exit:** `logos-kit` creates accounts and syncs against the standalone sequencer.

### S3 · Policy authority, approvals, tx build/prove/sign, preflight, CLI
- **Policy:**
  - `Caller = WalletUi | LocalOwner(CLI) | Module(name) | Host | Bridge | Unknown`, derived from `current_caller()` in the shim only. `Host`, `Bridge` and `Unknown` fail closed.
  - The encrypted `GrantStore` is keyed `(zone, requester, account, capability)`, following the S0 probe result.
  - A `PendingRequest` holds the handle, requester, intent, zone, account, canonical request hash, deadline and UI module.
- **Approval hardening.** All `ui_qml` code shares one process, so a name alone can be impersonated (doc 04 §3.3). The fix follows the EVM keystore:
  - the approving UI **echoes the canonical request hash**, and the core compares it;
  - **only one pending request is rendered at a time**;
  - the wallet must be unlocked; **re-auth (password/unlock proof) is required for first connect, above a value threshold, and for private spends**;
  - approval is an atomic CAS consume.
- **At sign time:**
  - re-fetch nonces and the program header → `StaleApproval` on any change;
  - private txs: the circuit's public effects must equal the approved `expectedEffects`;
  - approvals expire on account/zone switch, restart, or deadline.
- **Preflight checks.** Each is scoped per program after verifying the actual 0.3 behaviour on standalone. (The "silent discard to an uninitialised recipient" is a v0.2 premise; doc 05 §1.6 says a 0.3 token `Transfer` deposits into an empty shard.)
  - fee-payer balance vs `max_fee`
  - per-account nonce serialization
  - token holding existence
- **Prover worker:**
  - single slot plus a cancel token;
  - phases: building → proving → signing → submitted → included;
  - `StatusStore` is readable only by the requester and WalletUi;
  - events carry the handle only.
- **Status and gas:**
  - `outcome` comes only from an event or an own-account invariant; otherwise `unknown`;
  - gas estimate comes from `getFeeState`; gas used is taken when available, else "unavailable".
- **`logos-kit` CLI:**
  - Commands: init / restore / unlock / lock; `account new|list|label`; balance; send; `token send|balance`; shield / deshield; faucet; `testimonial post|evidence`; `verify-program`; status; `zone add|use`; backup / restore.
  - It runs through the same policy as `LocalOwner`. The TTY confirmation shows the decoded summary **and the estimated fee**.
  - `--yes` is allowed only in `demo.sh` and e2e.
- **Confidence test:** `e2e/rust/tests/authz.rs` checks that:
  - a dApp can't approve;
  - `Unknown`/`Host` are denied;
  - no cross-caller status reads are possible;
  - approvals can't be replayed;
  - stale approvals are rejected;
  - **impersonation (a wrong echoed hash)**, **cancel**, and **module restart** are handled.
- **Review:** code-review + security-review.
- **Exit:** a public send and a shield (with progress) via `logos-kit` on standalone.

### S4 · Decoders, tokens, source verification, faucet
- **Tokens:**
  - A configurable `(program account, decoder)` list.
  - Default: the 0.3 builtin **token** = `programs::token_account_id()`, the `token_core` re-export in `lez/programs/src/lib.rs`, which equals `AccountId::from_builtin_program_name(b"token")`. Same for the **ATA** program (`lez/programs/associated_token_account`).
  - Holdings are discovered via ATA/shards. Semantic reference: `lez/wallet/src/program_facades/{token.rs,ata.rs}`.
  - `xtask demo-token` creates a demo token for the video and e2e.
- **Decoders:**
  - built from wire bytes for native, token, ATA and testimonial;
  - output: `Summary{title, lines, outflows, authorities, fee, unknown}`;
  - **authority changes are flagged prominently.** This is the LEZ analogue of "unlimited approvals": LEZ has no allowances, but it has token authorities (LP-0013);
  - an unknown program requires explicit acknowledgement.
- **Source verification:**
  1. Read the header account → `ProgramHeader{image_id, immutable}` (`lez/programs/program_loader/core/src/lib.rs:189-221`).
  2. Look up the registry-lite entry: `{repo, commit, docker_tag, guest_path, lock_hash}`.
  3. `logos-kit verify-program`: clone @commit → `cargo risczero build` (docker `r0.1.91.1`) → compare the image id.
  4. Cache by `(zone, program account, image_id)`.
  5. Statuses: `verified_local` / `claimed` / `unknown` / `mismatch`, plus an upgradeable flag. Builtins are pre-verified by our CI, with the evidence committed.
- **Faucet:**
  - `trait FaucetBackend` → `Funded | RateLimited{retry_after} | Rejected | OutcomeUnknown`. Idempotent retry is reused from `lez-faucet-ffi/src/client.rs` `classify()`.
  - **Decision tree.** v0.3 code has no faucet/pinata program, and the LIP is stale. Take the first option that exists on launch day, per `xtask fingerprint`, and record the choice in PROGRESS:
    1. an official LEZ faucet (service or program);
    2. `token_mint_authority` FaucetMint (doc 04 §6.2) if it is ported to 0.3;
    3. L1 faucet + bridge deposit, reusing the LP-0022 bridge groundwork;
    4. last resort: our own **disclosed, self-hostable drip service** with a real per-account rate limit, funded from our testnet account.

    Every option is behind the same trait, so the mini-app never changes.
  - `GenesisSupplyBackend` for e2e and `demo.sh`.
  - A private target is one tracked multi-step operation: fund public → shield into the chosen private account.
- **Exit:**
  - the e2e faucet reaches `Funded`;
  - demo-token public and private transfers work;
  - `verify-program` works (completed after S5).

### S5 · Testimonial program + deploy + evidence (guest work runs in parallel from S1)
- **Guest:** `programs/testimonial/methods/guest/src/bin/testimonial.rs`, raw v0.3 `run_program(plan, apply)`.
  - Copy from `examples/program_deployment/methods/guest/src/bin/hello_world_with_authorization.rs` and `lee/state_machine/test_methods/guest/src/bin/event_emitter.rs`.
  - Design: doc 05 §3, adapted to 0.3 (SPEL doesn't support 0.3).
- **PDAs:** `stats(sub)`, `tm(sub,i)`, `author(sub,author)`. The last enforces one post per author, which guarantees distinct accounts.
- **Rules:**
  - the **author must be a public account** (a private author breaks the `stats` pre-state and leaks the private id);
  - `is_authorized`;
  - `timestamp_window ±120s`;
  - a `Posted` event;
  - text ≤280 B, username ≤32 B, plus the submission id;
  - the program is generic, keyed by submission id (reusable for LP-0024, LP-0001, LP-0022).
- **Build:** reproducible, in docker `r0.1.91.1` → `artifacts/testimonial.bin` + `image_id.txt`. `programs/testimonial/core` holds the shared types, PDAs and encoders.
- **Deploy:**
  1. **staging deploy** first, under a test submission id;
  2. production: `cargo xtask deploy-testimonial --immutable` via `ProgramLoader::deploy` (96 KiB segments), which writes `registry/programs.json`.
- **Evidence exporter:** `logos-kit testimonial evidence`
  - per calendar month: distinct authors, plus the strict ≥30 × ≥2 consecutive-month check;
  - prior activity per author;
  - **accepts multiple program accounts**, in case of a redeploy or reset;
  - daily **snapshots** (records + block hashes) to `adoption/snapshots/`.
- **Confidence test:** `e2e/rust/tests/testimonial.rs` covers deploy, 2 posts, a double-post rejection, the `index==count` retry, and the counts.
- **Exit:** deployed on the canonical 0.3 zone within days of launch; `verified_local`. **Hard input:** the brand must exist before the production deploy, because the submission id and the testimonial text name the wallet.

### S6 · TS codec + client + minimal theme + QML SDK bundle
- **`@logos-kit/codec`:**
  - root: borsh-lite, bn.js amounts, v0.3 Message/Witness, sha256, account ids;
  - `./sign`: BIP-340 via `@noble/curves` 2.x (**not** QML-safe);
  - integration test: TS output matches the Rust vectors.
- **`@logos-kit/client`** ("lez-viem"):
  - `createClient({transport, network}).extend()`;
  - actions with backoff polling;
  - `Account = json-rpc | local`;
  - a **lossless JSON** parser (u128 → string);
  - transports: `http`, `custom`, `basecampModule`.
- **Minimal `@logos-kit/theme`** (moved here, since S7 needs it): the **Tray light and Tray dark** token sets (ported from `apps/design-lab/src/lab/tokens.ts`, D14) plus `toQmlTokens()` → `Tokens.js`. S11 extends it.
- **`packages/qml-bundle`:** a port of `refs/connect-kits/_notes/artifacts/qml-transpile/pipe/{build.mjs,babel-plugin-qml-v4.cjs,src/qml-shims.js}`.
  - The `createLogosKit({callModuleAsync, openIntent})` facade exposes: connect, accounts, balance, `sendTransaction → {handle}` (the poller backs off and pauses when hidden), signMessage, signIn, requestFunds, typed errors, the **45 s intent timeout**, and the **busy guard**.
  - Output → `sdk/qml/LogosKit/logoskit.js`, target under 40 KB, plus a thin `LogosKit.qml`.
- **Confidence tests:**
  - lossless JSON on recorded RPC fixtures;
  - **QML engine gate:** `run_suite.sh` / `qmlrun.py` via uv with PySide6 6.9.2 + 6.11.1, diffed against Node.

### S7 · Basecamp core-module shim + wallet UI + first catalog release
- **Shim** (`LogosKitWalletModule`):
  - LWS-0 methods;
  - `ui_*` methods, WalletUi only;
  - `emit_request_updated(handle)`;
  - one tokio runtime.
  - Documented example: another Logos module calls the wallet via the generated typed client, `modules().logos_kit_wallet.<method>()`. This satisfies "usable by other Logos modules".
- **Wallet UI:** built strictly against `ux-spec.md`, using the module structure, Store/Sheet pattern, sandbox rules and dev loop in the **Basecamp / QML architecture** section.
  - **Provides:** `lez.wallet.connect`, `lez.transaction.send`, `lez.message.sign`, `lez.wallet.open`.
  - **Screens:**
    - **Onboarding:** create / restore / unlock + the first *private* account.
    - **Accounts:** badges, labels.
    - **Home/Assets:** native and tokens with real logos or an identicon.
    - **Send:** shows preflight results and the estimated fee.
    - **Receive:** public address; private receive code with fingerprint and QR.
    - **Activity:** queued rows showing proving phase and ETA (from the benchmarks), **fee/gas used or "unavailable"**, and balance buckets: spendable, pending, locked.
    - **ConnectSheet:** account picker.
    - **ApprovalSheet.**
    - **Grants:** view and revoke.
    - **Settings:** zones and sequencers; optional services (all off); every network endpoint listed; auto-lock; backup/restore; reveal mnemonic.
    - **Offline and error states.**
  - **No analytics, telemetry or third-party calls.**
- **ApprovalSheet:**
  - three sections: requested by / what you're signing / what this means;
  - `requesterName` plus package metadata, labelled "Unsigned";
  - a verification badge: program account, image_id, mutability;
  - an authority-change warning;
  - **estimated fee/gas**;
  - an acknowledgement checkbox for unknown effects;
  - re-auth where the policy requires it;
  - the button arms after 500 ms (UX only).
- **Visual design:**
  - `Logos.Controls` for structure;
  - `@logos-kit/theme` → `Tokens.js` (theme-clean, no hard-coded colours), **Tray** direction (D14): Tray dark by default in Basecamp, light available;
  - screen-by-screen parity with the `apps/design-lab` Tray prototype (home with account chips, keypad send, review with the balance change first, proof sheet with the progress ring, proof island, connect request); QA screenshots compared side by side with the prototype at 360/680/1024 px;
  - real logos;
  - **narrow and touch-ready layouts** for mobile Basecamp (Qt 6.11, testnet 0.4);
  - reuse `lez-programs/apps/shared/wallet` QML where it fits.
- **Intent flow:** `onIntentRequested` → `ui_createPending` → sheet → `respond({accepted, handle})`. The dApp then polls. `provides[].params` is declared exactly.
- **QA:** walk every `ux-spec.md` state at 360, 680 and 1024 px using the QML Inspector MCP, with screenshots saved to `docs/reviews/`. Add the one `tests/intent-flow.mjs` integration flow.
- **Publish the `lez.*` intent spec** (names, params, results, semantics) in the docs, and draft an upstream proposal for well-known intents.
- **Catalog fork:**
  - `logos-kit-modules` forked from `logos-modules-release-base`;
  - submodules added with `add-module.sh`;
  - multi-module callers use `module_path: submodules/<repo>/modules/<mod>`;
  - `rebuild-index.yml` plus a `release-on-merge` gate modelled on `refs/lez/lez-faucet/.github/workflows/`;
  - platforms: darwin-arm64, linux-amd64, linux-arm64;
  - **sign `.lgx` releases** if the release action supports `trustedSigners`; otherwise record that it is unsupported.
- **Names are final** (Logos Kit), so no rename pass. Module names are frozen from S0, because they become grant keys.
- **Review:** code-review, security-review, fidelity/UX.
- **Exit:**
  - clean Mac and Linux VMs install both modules from the fork's `logos-repo.json` URL;
  - public and private native and token flows work on 0.3.
- **Logos Storage encrypted backup + restore** is **not on the milestone critical path** (doc 09 §8). It ships in S9, and local storage stays authoritative.

### S8 · Mini-apps + dApp template + conformance kit + minimal docs ⇒ **FIRST RELEASE (adoption clock)**
- **`logos_kit_testimonial`:**
  - flow: connect → pick a **public** account → compose → approval (with fee) → proving/submit status → explorer link;
  - the text is **prefilled and validated so it names the wallet**;
  - an activity nudge ("fund & send first") keeps fresh accounts meaningful;
  - retries on `index==count` races.
- **`logos_kit_faucet`:**
  - account picker;
  - per-step states: rate-limit countdown, outcome-unknown "checking…", and the private shield step;
  - reports success or failure clearly.
- **`templates/basecamp-dapp/`:** a ui_qml flake with a vendored `LogosKit/`, README and icon, exposed as `templates.dapp`. It demos the in-flow faucet and the receipt callback.
- **Conformance kit:**
  - `logos_kit_wallet_fake`: deterministic fixture scenarios;
  - a capability matrix generated from the schema;
  - `just conformance <dapp>` via `logosctl`.
- **Minimal docs** (`apps/docs`, Fumadocs 16 + Next 16):
  - features: twoslash, `fumadocs-typescript`, `llms.txt` / `llms-full.txt`, `.md` routes, Orama static search;
  - content: an LWS-0 reference generated from `methods.json`, a QML SDK quickstart, the **testimonial and faucet worked examples**, the "other Logos modules" example, and the security/threat model;
  - `context7.json` + `AGENTS.md`;
  - setup from `refs/connect-kits/multichain/ts-sdks/packages/docs` and `refs/connect-kits/solana/framework-kit/apps/docs`; IA from wagmi `site/`.
- **Milestone exit:**
  - the doc 09 §8 first-release list is complete;
  - demo takes are recorded;
  - usability sessions and the Codex milestone review are done.

### S9 · CI hardening + prize E2E + README/demo contract
- **Workflows:**
  - `rust.yml`: fmt, clippy, tests, typify diff.
  - `nix.yml`: lgx-portable on macos-14, ubuntu, ubuntu-arm.
  - `e2e.yml`: the standalone sequencer **with `RISC0_DEV_MODE=1` on both sequencer and prover**. It runs init → faucet → public send → shield → private send → token transfer → testimonial deploy/post/export → stale/rejected approval.
  - `valid-proof.yml`: nightly real proving, mirroring LEZ's (about 60 min, `timeout-minutes: 150`).
  - `guest-repro.yml`.
  - `sdk-bundle.yml`: diff + QML gate.
  - `testnet-fingerprint.yml`: daily.
  - `verify.yml` for TS.
- **Logos Storage encrypted backup + restore.**
- **README:** setup, account management, step-by-step CLI and Basecamp usage, **local module build instructions and loadable assets** (LP-0021 L40), zone config.
- **`demo.sh` contract** (evaluators run it unmodified from a clean machine):
  - supported OS/arch;
  - prereq checks that print install commands;
  - sequencer: the standalone sequencer built from source at the pin (build time documented), or our own image published to ghcr. LEZ's `sequencer_service-standalone` image lives in a private registry, so we can't rely on it;
  - `RISC0_DEV_MODE=1`, with an optional `--real-proofs`;
  - non-interactive (`--yes`);
  - **no dependency on our hosted services**;
  - a clear exit status for each step.
- **Performance budgets** measured and recorded.
- **Exit:** `main` is green on every workflow, and `demo.sh` passes on a clean VM.

### A-track · Adoption (S0 → submission, continuous)

**Rule for anything public:** we *draft* forum and Discord posts, upstream issues and PRs, and outreach messages in `adoption/drafts/`. The user approves or posts them. Nothing public goes out without their go-ahead.

- **Start in S0**, per doc 09 §8 and Codex's advice:
  - a forum thread 1949 intro and progress post;
  - Discord #builder-hub;
  - pitch the upstream proposals (signature-authorized private spends, a compact notes feed);
  - invite builders early.
- **`adoption/tracker.md`:** one row per developer with:
  - repo;
  - **independence evidence** (not us, not each other, **not a Logos CC**; doc 06 says Alisher and Danish are CCs and do not count);
  - commit-history health;
  - SDK usage;
  - status.
- **Candidates:** the non-CC Basecamp builders in `refs/connect-kits/_notes/artifacts/census/tp_repos.txt`.
  - Start with the wallet-shaped apps: AMM UI, atomic swaps, private multisig, forum/whistleblower, polling.
  - Also the Discord builder working on ZK identity.
- **Channels:**
  - post our catalog URL in forum thread 1843 (module repository links);
  - fast support turnaround.
- **Upstream contributions:**
  - the user's CORS PRs;
  - our LEZ patch PRs.
- **Metrics:**
  - weekly evidence export plus daily snapshots;
  - monthly targets: ≥30 per calendar month, aiming for 75+;
  - a Discord/X testimonial log. Genuine use only; never manufactured.

### Kit / product track (after S8, during the adoption window)

**S10 · `@logos-kit/core` + `@logos-kit/react` + `@logos-kit/test`**
- **Core** (wagmi layering, from `refs/connect-kits/evm/wagmi/packages/{core,react}`):
  - `createConfig`, a zustand/vanilla multi-connection store, `persist` / `partialize` / migrate;
  - **SSR:** cookie storage + `cookieToInitialState` + hydration;
  - `createConnector`, where reconnect never prompts;
  - actions, plus `./query` with query keys `['lez', action, params]`.
- **Connectors:**
  - `mock`;
  - `walletStandard` (`@wallet-standard/app` discovery);
  - `embedded` (interface here, engine in S12);
  - `basecampBridge`: loopback `json_rpc_bridge` WS plus **our pairing flow**, labelled "unverified origin" and feature-flagged.
- **React hooks:** `LogosKitProvider`, `useAccount`, `useConnect`, `useDisconnect`, `useBalance`, `useSignAndSendTransaction` (exposes the proving phase), `useTransactionStatus`, `useSignMessage`, `useSignIn`, `useCapabilities`, `useRequestFunds`, a recent-transactions store, and `Register` augmentation.
- **`@logos-kit/test`:** mock + failure flags, a fake LWS-0 wallet, and a standalone `globalSetup`.

**S11 · `@logos-kit/theme` (full) + `@logos-kit/react-ui` (21st.dev design system)**
- **Theme:**
  - RainbowKit-style accent plus status tokens;
  - `toCssVars` (`--lk-*`), `toRnTheme`, `toQmlTokens`;
  - presets: **`trayLight` and `trayDark`** (D14; the RainbowKit dark/light/midnight presets are not shipped). Integrators can still override any token, RainbowKit-style (`accentColor`, `borderRadius`, `fontStack`).
- **CSS:**
  - Tailwind 4 `@import "tailwindcss/theme.css" layer(theme) prefix(lk)` plus utilities, **without preflight**, scoped under `[data-logos-kit]`;
  - a precompiled `styles.css` export;
  - a `"use client"` banner via tsdown `banner`;
  - `components.json` `tailwind.prefix`, so `21st add` output is auto-prefixed. Verify on the first component; fall back to a codemod.
- **Per component:**
  1. `21st search` → shortlist 3 → `21st get`;
  2. pick for fidelity against RainbowKit, ConnectKit and Privy;
  3. `21st add`;
  4. adapt: tokens, real logos, hooks, all states, a11y;
  5. record in `COMPONENTS.md`;
  6. `21st-ui-review`.
- **Seed component ids:**

  | Component | 21st id(s) |
  |---|---|
  | Dialog | 376 / 1248 |
  | Drawer | 31360 |
  | Segmented control (public/private) | 23552 |
  | Animated tabs | 1115 |
  | Stepper (ProofProgress) | 769 / 764 |
  | Toast | 3690 |
  | Copy | 10224 |
  | Tooltip / popover / select | 212 / 397 / 279 |
  | Status badge | 521 |
  | Pill (minimised proving) | 1600 |
  | QR | 1706 |
  | Skeleton | 19999 |
  | Spinner | 8677 |
  | Border trail (logo spinner) | 1135 |
  | Number ticker | 21513 |
  | Timeline (activity) | 1074 |
  | OTP / password | 23543 / 6278 |
  | Empty state | 19377 |

- **Composed components:**
  - ConnectModal: ConnectView union + history router, note 02 §8, with the connection states and the sign-in step;
  - **AccountModal**, **Network/Zone modal**;
  - WalletList (recent / detected / recommended);
  - AccountPicker, ConfirmSheet (+ `uiOptions`), ProofProgress, TxToast;
  - Avatar/identicon, Balance, AccountKindBadge, FaucetCard, ErrorShake;
  - **i18n** with lazily loaded locales.
- **API:** `LogosKitUIProvider`, `ConnectButton` + `.Custom`, `useConnectModal().open(): Promise<Account>`, `useAccountModal`, `useNetworkModal`.
- **Size budget:** core under 30 kB gzip.

**S12 · Embedded passkey wallet + CORS fallback + full docs**
- **`@logos-kit/keys`:**
  - PRF → HKDF → BIP-39 → the official LEE public and private tree + ML-KEM vpk (`@noble/post-quantum`), per note 05 §6;
  - integration test: TS keys match the Rust vectors.
- **`@logos-kit/embedded` engine:**
  - pinned credential;
  - IndexedDB storage encrypted with `storage_key`;
  - short unlock lifetime, with the key zeroized after;
  - approvals bound to the canonical tx;
  - public sign and send;
  - mnemonic export/import;
  - a wrapped-seed fallback;
  - private seams;
  - **registers itself via Wallet Standard**;
  - account centre, export, step-up.
- **`./dialog` / `./host`:**
  - Porto-style `{id, topic, payload}` messages over a MessageChannel, with exact origin/source checks;
  - create in a popup; sign in an iframe with a visibility check, falling back to a popup;
  - sources: `refs/connect-kits/passkeys/porto/src/core/{Dialog,Messenger}.ts` and `refs/connect-kits/evm/ox/src/core/WebAuthn.ts`, plus the Samsung Pass fix.
- **`apps/wallet`:** strict CSP, no third-party scripts; routes `/dialog`, `/popup`, `/auth-session`.
- **`apps/cors-proxy`:**
  - a Cloudflare Worker with origin and method allowlists and a rate limit;
  - disclosed and self-hostable;
  - used by the Playwright test and the playground until the user's CORS PRs land (`status-im/infra-logos` `ansible/group_vars/lez.yml`; LEZ `rpc_server/src/actor.rs` opt-in `CorsLayer`).
- **Full docs:**
  - Why (4 pillars), Quickstart for React / Expo / Basecamp, Concepts, Guides, per-hook/action reference (wagmi template), Playground, Troubleshooting, Build with AI;
  - a "no dashboard" config mapping (Privy parity);
  - landing page from 21st blocks: hero 5415, bento 4517, logo cloud 18216, features 8706, footer 1614;
  - fidelity check against the wagmi, RainbowKit and Privy docs.
- **Integration test:** Playwright + CDP virtual authenticator (`hasPrf`): create → connect → sign and send against standalone via the proxy, plus foreign-origin rejection.
- **Review:** security-review.

**S13 · `create-logos-kit` + playground + web testimonial client**
- **CLI:** cac, prompts, picocolors; `frameworks.ts`; `templates/` with `_gitignore` renaming. Source: `refs/connect-kits/evm/wagmi/packages/create-wagmi`.
- **Templates:**
  - `vite-react` (default), `next`, `headless`;
  - **`program-call` = the web testimonial client** (D2), writing to the same program;
  - a `basecamp-module` pointer that runs `nix flake init -t #dapp`.
- **Expo:** the template is added in S14, after `@logos-kit/react-native` exists.
- **Playground:** a kitchen-sink web app.
- **CI:** template smoke build.

**S14 · React Native / Expo + mobile testimonial client**
- **`@logos-kit/react-native`:**
  - RN `Modal` + `Animated` + `react-native-svg`, sharing the ConnectView and theme tokens;
  - AsyncStorage;
  - SecureStore (`WHEN_UNLOCKED_THIS_DEVICE_ONLY`, namespaced keys);
  - `react-native-passkeys` PRF (base64url results, per the verified source);
  - an `openAuthSessionAsync` hosted fallback;
  - `./shim` (`getRandomValues`, `TextDecoder`), loaded before `expo-router/entry`.
- **`@logos-kit/expo-plugin`:** `createRunOncePlugin` → associatedDomains, FaceID, `<queries>`, build-properties.
- **`apps/expo-example`:**
  - uses SDK 52+ automatic monorepo config;
  - if RN libraries fail under pnpm isolation, the Expo docs recommend `nodeLinker: hoisted`. That is workspace-wide, so decide then, recording the trade-off (a separate sub-workspace is the alternative);
  - includes the **mobile testimonial client** (D2).
- **`expo` template** added to create-logos-kit.
- **Patterns from:** `refs/connect-kits/evm/appkit-react-native` (patterns only), thirdweb's `react-native` export condition, `passkeys/react-native-passkeys`.

**S15 · Private accounts on web/mobile** (doc 09 §3.4)
- **Key tiers:** Spend / View / ReceiveCode capabilities.
- **LEZ Link v0 transport** (note 03 §Recommendations): X25519 → XChaCha20-Poly1305 JSON-RPC over a small untrusted WebSocket relay, with QR plus a SAS pairing screen **in the Basecamp wallet**. The relay is optional, disclosed and self-hostable (agari-box via Coolify).
- **Provers:**
  - `PairedDeviceProver`: the desktop re-shows the approval locally and never accepts opaque jobs;
  - `KeyFreeShieldProver`: the client recomputes the commitment and ciphertext before signing;
  - `UserOwnedProver`: a reproducible VM image;
  - TEE: an opt-in, labelled weaker tier, later.
- **Sync:** a JS private-view worker (birthday, tip-first), plus an optional compact notes feed from the user's own indexer.
- **Payments:** payment-request links and a fingerprint.
- **Phone spike:** on-device risc0 (E8).
- **Review:** security-review.

**S16 · Release hardening**
- **Publishing:**
  - changesets 3 + npm **trusted publishing** (`id-token: write`, provenance);
  - canary snapshots on `main`;
  - pkg-pr-new PR previews;
  - size-limit comments;
  - docs preview deploys.
  - Workflow structure from `refs/connect-kits/evm/wagmi/.github/workflows/{verify,pull-request,changesets}.yml`.
- **npm READMEs** at wagmi grade (checked for fidelity against wagmi's and RainbowKit's npm pages), plus `publint --strict` and `attw`.
- **Performance budgets** re-measured.

### S17 · LP-0022 track (when testnet 0.4 ships)
- **Features:**
  - L1 accounts and transfers (own derivation per the Logos Wallet Technical Standard; never reuse LEZ ids);
  - stake / unstake / claim;
  - bridge with a durable cross-chain operation journal and pending/settled states;
  - multi-zone, with per-zone sequencer switching that loses no state;
  - L1 testimonial inscriptions and a faucet covering both layers;
  - the SDK across chain and zones;
  - the network/zone modal becomes the L1 ↔ zones toggle.
- **LP-0022's own adoption tranche:**
  - 5 **new** independent Basecamp apps using the L1/staking/bridge/multi-zone APIs;
  - 100 L1 inscriptions over ≥2 months (≥20 per month);
  - 20 Discord + 20 X testimonials about those features;
  - the LEZ-side testimonials are waived only if we won LP-0021 on the same codebase.
- **Then the LP-0001 v2 hooks:** NFT enumeration, the proof-request capability, a disclosure preview.

### S18 · Submission
- **Solution file:** `solutions/LP-0021.md` in a fork of `logos-co/lambda-prize`, from `refs/lambda-prize/solutions/LP-0000.md`: FURPS self-assessment and the success-criteria checklist.
- **Narrated video** (`direct-demo-video` skill; it is installed). It covers:
  - key and multi-account setup, including a private account;
  - faucet funding;
  - send and receive;
  - token usage;
  - the testimonial app: connect → select → approve → create.
- **Evidence pack:**
  - the 10 independent apps with repos and independence notes;
  - evidence export plus snapshots with per-month counts;
  - Discord and X links;
  - the fork's `logos-repo.json` URL.
- **Authorship Q&A prep:** architecture walkthrough notes (LP-0021 L122).
- **Before opening:**
  - clean-VM `demo.sh` passes;
  - the Codex pre-submission review is done.
- **Open the PR only when every criterion is met** ("not a showcase"). Maximum 3 submissions, 1 per week. **The user gives the final go.**

---

## Deployment and hosting
- **Vercel** (team `blockchain-oracles-projects`): `apps/docs`, `apps/playground`, `apps/wallet` (static; strict headers in `vercel.json`).
- **Domain:**
  - registered with `namecheap-cli`, DNS on Cloudflare;
  - subdomains: `docs.`, `wallet.` (the passkey RP ID; AASA and `assetlinks.json` under `/.well-known/`), `play.`;
  - never leave DNS dangling (memory `user-infra`).
- **CORS proxy:** Cloudflare Worker (wrangler).
- **Relay (S15) and user-owned prover image:** agari-box via Coolify. Optional, never mandatory.
- **Module catalog:** GitHub Releases on the catalog fork.
- **npm:** trusted publishing.
- **Standalone sequencer image:** optionally publish our own to ghcr for `demo.sh` speed.

## Integration-confidence tests (complete list; no UI tests)
1. Codec and key vectors: Rust vs upstream, TS vs Rust, TS in both QML engines.
2. Keystore: crash, disk full, wrong password, network-drop resync.
3. `authz.rs`, including impersonation, cancel and restart.
4. Prize E2E on standalone in dev mode, plus nightly real proofs.
11. The QML intent flow (`tests/intent-flow.mjs`, via qt-mcp): connect → approve → send → status in real Basecamp.
12. Core-module API through `logoscore-py` against the real module.
5. Testimonial deploy / post / race / evidence.
6. Guest reproducibility.
7. QML bundle gate.
8. Lossless JSON.
9. Embedded wallet via a virtual authenticator, plus origin rejection.
10. Conformance-kit happy path.

## Verification (end to end)
- **Local:**
  1. `just e2e` (faucet → public send → shield → private send → token → testimonial → stale rejection);
  2. `just build-modules`;
  3. install both `.lgx` in Basecamp;
  4. run the testimonial and faucet apps by hand through connect → select → approve → tx, checking every state against `ux-spec.md`.
- **Live 0.3** (once `xtask fingerprint` reports 0.3):
  1. staging deploy, then production deploy;
  2. `verify-program` → `verified_local`;
  3. post from Basecamp;
  4. the evidence export shows it;
  5. it appears on explorer.testnet.lez.logos.co.
- **Clean VMs** (macOS and Linux):
  - install from the catalog fork URL;
  - `demo.sh` runs unmodified.
- **CI:** all workflows green on `main`.
- **Kit:**
  - the playground connects to the embedded wallet and to the Basecamp bridge;
  - `pnpm create logos-kit` templates build;
  - the Expo dev client sends a public tx;
  - the web and mobile testimonial clients post to the same program;
  - the docs build, and `llms.txt` resolves.

## Inputs needed from the user (with the stage that needs each)
| Input | Needed by | Why |
|---|---|---|
| **GitHub go-ahead:** create the public `logos-kit` repo + the `logos-kit-modules` catalog fork, enable CI. They can live under `Blockchain-Oracle`, or under a new `logos-kit` org (the name is free) | S1 (Linux builds, CI), S7 (catalog) | Pushing needs explicit approval |
| ~~Brand~~ | done: **Logos Kit** | — |
| **Domain** (we can register it via namecheap-cli once approved) | S8 docs, S12 RP ID | Hosting and passkeys |
| **npm org `@logos-kit`** (trusted publishing). The local npm token is expired, so this needs `npm login` | S6 canaries, S16 | Publishing |
| **Discord/X accounts** for outreach | A-track, from S0 | Community posts |
| KasFlow `sha256(pubkey)` patch | separate from this project | The user decides |
