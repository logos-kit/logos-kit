# LP-0021 criteria audit (2026-10-06)

Every bullet of `prizes/LP-0021.md` and the README submission rules, checked against the code on `main` and live read-only data. A status is set from code and run evidence, never from `PROGRESS.md` alone.

**Legend.**
- **MET**: done, with evidence.
- **PARTIAL**: works, but a judge could fail it as it stands.
- **NOT MET**: missing.
- **BLOCKED-ON-CUTOVER**: built and proven on the preview network; only the official-testnet cutover is missing.
- **Cutover?** column: **yes** means the criterion can't be fully met before the cutover (`docs/dev/cutover-0.3.md`, issue #2).

## Inputs and method

- **Spec.** `logos-co/lambda-prize` @ `7a52d8f`, pulled 2026-10-06.
  - `prizes/LP-0021.md` has **not changed** since `93b7f9a` (2026-09-24, "Open LP-0021").
  - `git log -p --since=2026-09-22 -- prizes/LP-0021.md README.md`: the only README changes are LP-0026 (added, opened, retiered) and LP-0001 (opened 2026-10-01). Commit `f8989bd` "confirm the testnet 0.3 endpoint" edits **LP-0001 only**. LP-0021 already named `https://testnet.lez.logos.co`.
  - `solutions/LP-0000.md` (the template) is unchanged.
- **Code.** `logos-kit` `main` @ `77e62ab` (2026-09-30).
  - While this audit ran, the cutover session's **uncommitted** re-pin to LEZ `v0.3.0` (`db66590`) appeared in the working tree: `crates/xtask/src/main.rs`, `crates/wallet-engine/src/lib.rs`, `flake.*`, `programs/testimonial/Cargo.*`, `protocol/vectors/*`. It was not audited.
  - `docs/dev/pins.md` and `cutover-0.3.md` still name `f7fda38` as the pin.
- **Read-only checks run.**
  - Fetched the catalog `logos-repo.json` and `index.json`.
  - HTTP checks on the docs pages.
  - `gh run list`, `gh issue list`, `gh api …/compare`.
  - RPC `getProgramIds` / `getLastBlockId` on the testnet and the preview.
  - Reading code, tests, e2e scripts and screenshots.
- **Not run:** no builds, no e2e, no GUI.

### Cutover facts verified today (they decide several rows)

| Fact | Evidence |
|---|---|
| The official testnet runs 0.3 (since 2026-10-01). Wire format decodes with our code. | Issue #2, opened by `daily.yml`: `version 0.3`, `headDecodesAsPinned: true`, `base_fee_exec 8`. Tip block 11,843 at audit time; preview tip 61,613 |
| `v0.3.0` = `db66590`. That is **19 commits / 42 files** after the committed pin `f7fda38`. | `gh api …/compare/f7fda38…v0.3.0`. The changes include new `privacy_preserving_circuit.bin`, `token.bin` and `associated_token_account.bin` artifacts, and `refactor(lee_core)!: reserve apply-time chained calls on ApplyOutput` |
| The live program images differ from ours. | Token program: testnet `912d412c…14ab`; our pin and `registry/builtins.json` `8718d36e…f8b5` (preview matches the pin). Privacy circuit: testnet `189513eb…2721`; preview `106c0028…d1c8` |
| ⇒ What happens if a judge points the released wallet 0.1.3 at the testnet | Private proofs use the wrong circuit and would be rejected. Token sends would show the token program as `mismatch`, drawn as a red "Unverified" badge (`verify.rs:263-292`, `TxSummary.qml:132`). The testimonial guest must be rebuilt against the new `lee_core`, so its image id changes. |
| No testnet faucet and no testnet testimonial program are configured. | `service.rs:2046-2054` (`faucet_label` gives None for `lez-testnet`). `packages/codec/src/programs.ts:78-81` and `registry/programs.json` list only `lez:preview` |
| Defaults still point at the preview network. | `session.rs:106` (zone order), `logos-kit-cli/src/main.rs:41` (`default_value = "lez-preview"`), `sdk/qml/LogosKit/LogosKit.qml:21` |

---

## Functionality

| # | Criterion | Status | Evidence | Gap → smallest fix | Cutover? |
|---|---|---|---|---|---|
| F1 | **LEZ assets**: own, send and receive native and token assets, from public and private accounts | MET | **Routing:** one transfer intent whose route follows from the two accounts: public, shield, unshield or private (`tx.rs:47-68`, `:910-922`).<br>**Receive:** private receive codes `lezpriv1:` (`service.rs:1993-2020`).<br>**UI:** route and asset picker `SendFlow.qml:51-57,151-165`; balances and tokens per account `Home.qml:149-186`.<br>**Real proofs on preview:** `e2e/preview-flows.sh:30-57`: faucet, public send, shield, private→public, token public, token public→private, testimonial.<br>**Dev proofs:** `e2e/tokens.sh:53-70`: a token send *from* a private account, token unshield, and a private payment to another wallet's keys found by sync.<br>**Demo:** `e2e/demo.sh:126-170`, 16/16 local and 14/14 preview per `PROGRESS.md:190` (no log kept). | No live real-proof run of a **token send from a private account**, or of a private→private native send. Add both steps to `demo.sh` and `preview-flows.sh` (S). | yes (official network) |
| F2 | **Token program**: own and transfer fungible tokens from public and private accounts | MET | **Decoding:** all 7 token instructions (`decode.rs:257-411`).<br>**Holdings:** each account's own token shard plus tracked ATAs (`tokens.rs`).<br>**Preflight:** checks the recipient slot (`tx.rs:379-404`).<br>**CLI:** `token create/list/track/ata` (`logos-kit-cli/src/main.rs:192-210`).<br>**E2E:** as in F1. | The GUI can't create or track a token: no `ui_*` method for it (`service.rs:413-830`). See U6. | yes |
| F3 | **Multiple accounts**, public and private, and switching between them | MET | **GUI:** add public or private accounts and rename them (`AccountsView.qml:20,64,78`); account switcher on Home.<br>**Recovery:** all accounts derive from one phrase, and restore finds them again (`tests/e2e_sync.rs:68`).<br>**CLI:** `account new [--private] / list / label`.<br>**Proof:** `docs/reviews/s7/17-accounts-480.png`; `demo.sh:127-130` creates 2 public accounts and 1 private. | — | no |
| F4 | **Wallet Provider SDK** (documented): request account access, read balances and state, propose transactions | MET | **Engine methods:** LWS-0 dispatch `service.rs:355-405` (getAccounts, getBalance, readAccount, signAndSendTransaction, getTransactionStatus, chainId, openExplorer, disconnect), plus the connect, send, sign, signIn and requestFunds intents.<br>**QML SDK:** `packages/qml-bundle/src/facade.ts:206-273` (connect, getWalletBalance, readAccount, transfer, sendCall, postTestimonial, requestFunds, watchTransaction), shipped as `sdk/qml/LogosKit`.<br>**npm:** `@logos-kit/{client,codec,protocol,theme}` 0.1.0.<br>**Docs:** `sdk/qml.mdx`, the generated `reference/methods.mdx`, `guides/*`. | **By design:** apps may propose only a single public instruction. A transfer from a private handle is refused with 6100 (`service.rs:1133-1156`); private transfers start in the wallet. Say so plainly in the submission (S). | no |
| F5 | **Selection and approval flow**: an account picker, then an approval prompt, before anything is signed or submitted | MET | **Connect sheet:** account picker plus a separate private-read consent (`IntentView.qml:121-128,254-300`; shot `s8/faucet/02-wallet-connect-private-440.png`).<br>**Approval sheet:** `ApprovalView.qml`. Only the wallet UI or the local owner can approve (`policy.rs:30-34`; `ui_*` guard `service.rs:347-352`).<br>**Tests:** `tests/authz.rs:47` `only_the_wallet_approves_and_only_once`, `:235` `a_dapp_without_a_grant_cannot_propose`.<br>**Real Basecamp:** `e2e/basecamp.sh` + `tests/intent-flow.mjs` (`docs/reviews/s7/basecamp/10-connect-sheet.png`, `12-approval-sheet.png`) and `e2e/basecamp-apps.sh`. | Transactions have no per-transaction account picker: an app uses an account it was connected to, and the sheet shows **From**. Defensible; mention it in the submission. | no |
| F6 | **Testimonial mini-app** on the official zone, on a standard LEZ program. Each testimonial carries text, an optional username, the unique LP submission id and an on-chain timestamp. Full connect → select → approve → tx. | BLOCKED-ON-CUTOVER | **Program:** `programs/testimonial`. Text 1–280 B, `username: Option` ≤ 32 B, submission 1–32 printable ASCII (`core/src/lib.rs:26-57`). The submission id is `LP-0021/logos-kit` (`testimonial.rs:34`). One record per (submission, author).<br>**Timestamp:** `timestamp_ms` is bound by the transaction's timestamp validity window `[ts−2 min, ts+10 min)`, which the sequencer enforces (`methods/guest/src/lib.rs:67-71`). Posts must be top-level (`:39`).<br>**Deploy and build:** immutable deploy; reproducible build (`artifacts/build.json`, `guest-repro.yml` green).<br>**App:** optional name field (`modules/logos_kit_testimonial/qml/Main.qml:489-494`); the text must name Logos Kit (`:105`).<br>**Proof:** `e2e/testimonial-app.sh`, `e2e/basecamp-apps.sh` (real Basecamp); shots `s8/testimonial/01…12`, `s8/basecamp/10-12-*`.<br>**Preview program:** `4vjENy…R8XK`. | On the official zone:<br>(a) rebuild against v0.3.0 `lee_core` (new image);<br>(b) immutable `testimonial deploy` on `lez-testnet`;<br>(c) add entries to `registry/programs.json` and `TESTIMONIAL_PROGRAMS`;<br>(d) set up a testnet faucet so new users can pay the fee.<br>All four are runbook §4–5. No SPEL IDL, which LP-0021 doesn't require. | **yes** |
| F7 | **Faucet mini-app**: SDK account picker, reports success or failure, handles rate limits | BLOCKED-ON-CUTOVER | **App:** `modules/logos_kit_faucet/qml/Main.qml`: connect public and private accounts; states funded, rate-limited countdown (`:169-191`), unconfirmed, declined and failed; the private path asks the user to approve a shield.<br>**Engine:** `FaucetBackend` (`faucet.rs`).<br>**Drip v2:** `crates/logos-kit-drip`: durable ledger, per-IP limit, `Retry-After`.<br>**Proof:** `e2e/faucet-app.sh`; shots `s8/faucet/03-funded`, `04-rate-limited`, `10-private-funded`, `s8/basecamp/20-21`. | The spec says "the LEZ faucet". `lez:testnet` has no backend yet (`service.rs:2046-2054`). Pick the official 0.3 faucet if one exists, otherwise run a testnet drip (runbook §5, M). | **yes** |
| F8 | **Testnet 0.3**: the wallet works end to end on the canonical LEZ zone | BLOCKED-ON-CUTOVER | Every flow is proven on preview LEZ 0.3-rc1 with real proofs, and the daily fingerprint (`daily.yml`) runs. | Run runbook §1–§9:<br>• re-pin (in flight);<br>• `just verify-builtins` at v0.3.0;<br>• testimonial deploy and testnet faucet;<br>• testnet as the default network;<br>• a 0.1.4 catalog release;<br>• `LK_ZONE=lez-testnet e2e/preview-flows.sh` with real proofs. | **yes** |

## Usability

| # | Criterion | Status | Evidence | Gap → smallest fix | Cutover? |
|---|---|---|---|---|---|
| U1 | The SDK is usable by other Logos modules and third-party dApps: query balances, request account access, request transfers and contract interactions | MET | **Core module:** `logos_kit_wallet`, with a LIDL contract (`modules/logos_kit_wallet/logos_kit_wallet.lidl`) that any module can call (`logosctl call … lez_getCapabilities`).<br>**Contract calls:** `sendCall` and `lez_signAndSendTransaction` take a generic instruction.<br>**For app builders:** a conformance kit (`modules/logos_kit_wallet_fake`, `docs/dev/conformance.md`, `just conformance`) and a dApp template (`templates/basecamp-dapp`). | The "other modules" pattern (`guides/other-modules.mdx`) says itself that it hasn't been run in Basecamp. Run it once (S). | no |
| U2 | Basecamp app GUI with local build instructions and loadable assets | MET | **Build steps:** `README.md` "Build the modules from source" (`nix build .#lgx-portable` for 4 modules) and `wallet/install.mdx` "From source".<br>**Assets:** `.lgx` files in the catalog releases.<br>**Proof:** `e2e/catalog-install-gui.sh` (`docs/reviews/s7/catalog/01-06`). | — | no |
| U3 | Modules published to a catalog (a fork of `logos-modules-release-base` releasing through `logos-modules-release-action`), with the `logos-repo.json` URL in the submission | MET | **Repo:** `github.com/logos-kit/logos-kit-modules`. The GitHub API reports `template_repository: logos-co/logos-modules-release-base` and `fork: false`.<br>**Workflow:** `_release-module.yml:57` uses `logos-co/logos-modules-release-action/.github/workflows/release.yml@v1`.<br>**URL (live today):** `https://raw.githubusercontent.com/logos-kit/logos-kit-modules/refs/heads/main/logos-repo.json`. Release DID in `trustedSigners`.<br>**Index** (`generatedAt` 2026-10-05): wallet (core) 0.1.3, wallet_ui 0.1.3, testimonial 0.1.1, faucet 0.1.1.<br>**Installs:** `e2e/catalog-install.sh` on macOS arm64 and Linux x86_64/arm64 (`PROGRESS.md:198`). | (a) The catalog is a template copy, not a GitHub fork (forks start with Actions off). Say so in the submission (S).<br>(b) 0.1.3 is built on rc1, so a cutover release is needed (runbook §7). | yes (for (b)) |
| U4 | Prompts identify the requesting dApp, the target account and, for transactions, the asset, amount and destination. Contract calls show a human-readable summary of their effects (assets or approvals moved, unlimited approvals). | **PARTIAL** | **Requester:** display name, module id and icon (`ApprovalView.qml:51-63`; `ui_appInfo`).<br>**"You send" card:** asset, amount and the **full** destination (`TxSummary.qml:29-86`).<br>**Context:** From account and who can see it (`ApprovalView.qml:122-131`).<br>**Effects:** decoded from the signed bytes (`decode.rs:139-185` plus the native, token, ATA and testimonial decoders). Authority use (mint, create, print) is flagged.<br>**Unknown calls:** a red notice, a required acknowledgement and the password (`ApprovalView.qml:162-169`).<br>**No allowances in LEZ:** the v0.3.0 token program has no approve or allowance instruction (`vendor/lez/lez/programs/token/core/src/lib.rs:13-72`; `decode.rs:5-8`).<br>**Shots:** `s8/basecamp/11-testimonial-approval.png`, `s7/21-tx-approval-480.png`. | **(1) Bug (found reading the code, not reproduced):** a token transfer an app proposes (SDK `transfer(…, definition)` or `sendCall(tokenTransfer…)`) reaches the sheet as intent kind `call`. `outToken` is set only for kind `transfer` (`ApprovalView.qml:40`) and `outNative` only for native outflows (`:34-39`). So the "You send" card, which also holds the **To** row, is hidden (`TxSummary.qml:31`). Then the effects filter (`ApprovalView.qml:103-109`) drops the one decoded line "250 of token … to …" because a recipient exists. The sheet ends up showing **no asset, amount or destination**. Fix: build the outflow from `summary.outflows` for any asset, and drop the duplicate line only while the card is visible. Add an app token transfer to `qa_wallet.py` or `app_harness.py` (S).<br>(2) `summary.signers` is filled (`tx.rs:1012,1223,1364`) but never shown. Add "Signs with …" rows, with a warning for any signer other than `from` (S).<br>(3) Unknown calls say "can't read what this does" but not "this program can move anything the signers hold". Reword (S).<br>(4) The "Unsigned app" banner shows on every request, even for catalog-signed apps (`ApprovalView.qml:64`, `IntentView.qml:242`). Fix the copy (S). | no |
| U5 | **Program source verification** status on the approval prompt (LP-0023-like registry) | **PARTIAL** | **Statuses:** `verified_local`, `claimed`, `unknown` and `mismatch`, read from the live program header (`verify.rs:1-15,241-345`).<br>**Builtins:** rebuilt in the pinned docker image (`registry/builtins.json`).<br>**Testimonial:** recognised by image and fixity.<br>**Registry-lite:** `registry/programs.json`, compiled into the wallet (`verify.rs:28-31`).<br>**CLI rebuild:** `logos-kit verify-program` rebuilds a program and caches it in `verified.json` (`verify.rs:487-503`).<br>**On the sheet:** Verified, Immutable and Upgradeable badges (`TxSummary.qml:118-142`). | (1) **Native transfers show no program row:** `tx.rs:913-921` and `:1184-1188` skip the check for the native program. Show "Native LEZ · built into the chain" (S).<br>(2) **Approvals ignore the local rebuild cache:** `verify::check` passes an empty cache (`verify.rs:224-226`); only CLI `program` reads it (`main.rs:1368-1379`). A third-party program the user rebuilt still shows "Unverified". Pass zone + `load_cache` into prepare (S).<br>(3) Adding a third-party program needs a new wallet build; there is no on-chain (LP-0023) registry or user registry file. Read an LP-0023 registry if one ships; until then allow a user-added registry file (M).<br>(4) `mismatch` is drawn as "Unverified" (`TxSummary.qml:132`); `badge()` in `ApprovalView.qml:42` is unused. Label it "Source mismatch" (S).<br>(5) On the testnet, token shows `mismatch` until the builtins are regenerated at v0.3.0. | yes (5) |
| U6 | **UX quality**: polished and usable by a non-expert (judged on overall impression) | **PARTIAL** | **Design:** Tray redesign, LogosKitUi v2 (`PROGRESS.md:187`).<br>**States:** loading, offline, syncing and empty states; proof ring and island (`ProofView.qml`, `Island.qml`).<br>**Accessibility:** focusable controls, contrast ≥ 4.5:1, reduced motion.<br>**Screenshots:** `docs/reviews/s7`, `s8`, `revamp/before-after`. | (a) No sessions with non-expert users yet (`PROGRESS.md:206`).<br>(b) A judge in Basecamp **can't get a token** without the CLI: no create, track or import in the GUI.<br>(c) "≤ 134,400,000 LEZ" fee cap next to a 5 LEZ send, and no actual fee shown afterwards.<br>(d) The "Unsigned app" banner (U4).<br>(e) First open takes 16–40 s, and the core download is 223 MB (Basecamp side; `PROGRESS.md:131,199`).<br>(f) The preview has no explorer, so explorer links only work on the testnet (`service.rs:2057-2061`). | partly |
| U7 | Estimated gas and gas used per transaction, if testnet 0.3 provides them | **PARTIAL** | **Shown:** "Network fee (max) ≤ cap", from LEZ `max_fee_for(gas_limit 2,000,000)` (`TxSummary.qml:113-117`, `tx.rs:217-226`).<br>**Fetched, not shown:** `base_fee_exec` (`tx.rs:595-603`).<br>**Private:** "fee-exempt" (`ApprovalView.qml:133`).<br>**RPC limits:** LEZ 0.3 has no per-transaction gas receipt; `getTransaction` returns `(tx, block)` (`vendor/lez/lez/sequencer/service/rpc/src/lib.rs:73-76`), and there is no simulate method. | There's no gas estimate and no "used" or "paid" figure. Show gas limit × the current base fee as the estimate. After inclusion, show the fee paid (the payer's balance change, public transactions). State in the docs that the 0.3 RPC doesn't report gas used. Re-check on v0.3.0, including the private fee exemption (#859, runbook §3) (S). | yes (re-check) |

## Reliability

| # | Criterion | Status | Evidence | Gap → smallest fix | Cutover? |
|---|---|---|---|---|---|
| R1 | Wallet state survives restarts and network drops without corruption | MET | **Vault:** Argon2id + XChaCha20; writes are staged, fsynced and renamed, then the directory is fsynced (`vault.rs:11-13,240-249`).<br>**Tests:**<br>• `keystore.rs:77` `keystore_survives_crash_mid_write`<br>• `:160` `keystore_drop_persists_buffered_state`<br>• `session.rs:178` `network_drop_goes_offline_with_backoff`<br>• `:218` `zone_state_is_never_deleted_on_a_guess`<br>• `authz.rs:208` `a_restart_drops_pending_requests`<br>All run in `rust.yml` (`cargo test --workspace`). | A private proof in progress is lost on restart; no funds are lost. Open S2 follow-ups: vault write counter, zeroize (`PROGRESS.md:207`). | no |
| R2 | A dApp can't sign or submit, or read a private balance, without explicit approval for that account | MET | **Grants:** keyed per (zone, app, account, capability) (`policy.rs:48-68`).<br>**Private reads:** `lez_getBalance` on a private account needs `ReadPrivate` on a per-app opaque handle (`service.rs:1729-1770`, `private_handle` `:1967`). The private read needs its own tick (`IntentView.qml:121-128,270-277`).<br>**Signing:** every signer needs a `ProposeTx` grant, with no membership oracle (`service.rs:1191-1218`). Modules can never approve.<br>**Tests:** `e2e_service.rs:84-240` (4100 for an ungranted signer, the private account isn't shared), `authz.rs`. | No test asserts that `lez_getBalance` on a private account (raw id or handle) is refused before consent. Add one (S). | no |
| R3 | No mandatory external services; optional ones disclosed and possible to disable; analytics opt-in only | MET | **Disclosure:** Settings → Privacy says "no analytics or third-party calls" and lists the sequencer, faucet and proving (`SettingsView.qml:112-117`).<br>**On request only:** the faucet is called only when the user asks. Explorer links open only on a user action and are rate-limited (`service.rs:1531-1584`).<br>**Nothing remote:** fonts and icons are bundled; no analytics code. | Today the default network is our own preview sequencer and drip on one host (`session.rs:71-72`). That is disclosed; after the cutover the default becomes the official endpoint. | yes (default) |
| R4 | Remote persistence, if any, uses Logos Storage with client-side encryption | MET (N/A) | There is no remote persistence. Backups are encrypted local files (`backup.rs`, `logos-kit backup export`). | A Logos Storage backup is planned (`PLAN.md:595`) but optional for this criterion. | no |

## Performance

| # | Criterion | Status | Evidence | Gap → smallest fix | Cutover? |
|---|---|---|---|---|---|
| P1 | Responsiveness gives an adequate UX (subjective) | **PARTIAL** | **Measured:**<br>• QML SDK load 18–27 ms (S6)<br>• module load 1.1 s; engine init 0.01 s warm (`PROGRESS.md:199`)<br>• background sync, polling that pauses while hidden, proof progress UI<br>**Disclosed:** private proofs take 4–8 min and about 4.3 GB of memory on an M-series Mac (README "Accounts"). | (a) The `PLAN.md:232-240` budgets were never measured or recorded.<br>(b) Machines with little memory are untested.<br>(c) No sessions with real users.<br>Fix: record the budgets and the memory requirement in the docs (S); hold the sessions (M). | no |

## Supportability

| # | Criterion | Status | Evidence | Gap → smallest fix | Cutover? |
|---|---|---|---|---|---|
| S1 | Deployed and tested against Logos testnet 0.3 | BLOCKED-ON-CUTOVER | Preview only. Runbook `docs/dev/cutover-0.3.md`; issue #2 is open. | Runbook §9–§10: routes on the testnet with real proofs, and the evidence snapshot. | **yes** |
| S2 | Built with `logos-module-builder`; installable on Linux and macOS | MET | **Builders:** the core flake uses `mkLogosModule` (`modules/logos_kit_wallet/flake.nix`); the UI and the apps use `mkLogosQmlModule` (`ui_qml`, the builder's UI type), pinned at `4b79982`.<br>**Variants:** `darwin-arm64`, `linux-amd64`, `linux-arm64` (`docs/dev/releasing.md:37`).<br>**Clean installs:** macOS arm64 and Linux x86_64/arm64 (`e2e/catalog-install.sh`); GUI install on macOS (`e2e/catalog-install-gui.sh`). | No macOS Intel variant. No Linux Basecamp GUI run (`PROGRESS.md:208`) (M). | no |
| S3 | E2E tests against a real standalone sequencer, in CI, green on the default branch | MET | **What runs:** `.github/workflows/e2e.yml` builds `sequencer_service --features standalone` from the pinned source, then runs `e2e/cli.sh`, `e2e/testimonial.sh` and the engine `e2e_sync`/`e2e_service`/`authz` tests.<br>**Status:** the last `main` push (2026-09-30 09:51) was green on Rust, TS+docs, E2E and the QML gate. The nightly `valid-proof.yml` (real proofs) has been green every day through 2026-10-05. Badges are in the README. | `e2e/tokens.sh` (token routes) isn't in CI, although PLAN S9 lists token transfers. Add the step (S). CI must turn green again after the v0.3.0 re-pin. | yes (re-green) |
| S4 | README covers setup, account management, and step-by-step use through the CLI and the Basecamp app | **PARTIAL** | `README.md` covers the catalog install, accounts, CLI, networks, building modules and `demo.sh`. | (a) **Stale:** "official testnet still runs 0.2" (`README.md:46,120,212`).<br>(b) The "CI ⏳ S9" status row (`:61`) contradicts the green badges.<br>(c) The Basecamp steps stop at create/restore + Add. Add numbered steps: private account, send and receive, receive code, tokens, connected apps (S). | yes (a) |
| S5 | SDK docs walk through the testimonial and faucet apps: connect → account selection → approval → transaction | MET | `apps/docs/content/docs/guides/testimonial.mdx` (Connect, Read, Compose, Propose/approve, Follow) and `guides/faucet.mdx` (Connect both kinds, Pick, Request, private path). Both pages are live (HTTP 200 at `logos-kit-docs.vercel.app/docs/guides/{testimonial,faucet}`), along with the quickstart. | Stale "0.2" lines: `index.mdx:64`, `concepts/networks.mdx:7`, `help/troubleshooting.mdx:61` (runbook §8). | yes (text) |

## Adoption

The adoption rules haven't changed in the spec.

**Timing.** The official chain was reset on 2026-10-01. If posting starts in October and October and November each reach ≥ 30, the earliest qualifying solution PR is about **2026-12-01**. If October misses 30, it's early January 2027.

| # | Criterion | Status | Evidence | Gap → smallest fix | Cutover? |
|---|---|---|---|---|---|
| A1 | **10 independent third-party devs**, each shipping a Basecamp UI app that uses the SDK, with a genuine commit history | NOT MET | `adoption/tracker.md` has 0 rows (candidates only). The outreach drafts in `adoption/drafts/01-04` haven't been posted. Enablers exist: the template (`nix flake init -t …#dapp`), the conformance kit, docs and npm. | Approve and post the drafts, then onboard builders one by one and log independence evidence (L, calendar-bound). Apps can start on the preview but must work on the official zone. | yes (functional on testnet) |
| A2 | **150 on-chain testimonials** through our app on the official zone, ≥ 150 distinct accounts, text that names our wallet | NOT MET | **Exporter ready:** `logos-kit testimonial evidence` (per-month distinct authors, `priorTxs`/`hasPriorActivity` at `testimonial.rs:270-271,413-414`). The app requires "Logos Kit" in the text (`Main.qml:105`).<br>**But:** 0 testimonials on the testnet, and no program there. | Deploy (F6), then schedule daily snapshots into `adoption/snapshots/` (runbook §10) and run the campaign (L). | **yes** |
| A3 | Sustained: ≥ 2 months, ≥ 30 new each month | NOT MET | Time-gated; the window can't start before A2's deploy. | As A2; plan for ≥ 30 in the first calendar month. | **yes** |
| A4 | 30 Discord testimonials describing real use | NOT MET | None. `adoption/drafts/02-discord-builder-hub.md` is unposted. | Community work once users exist (L). | no |
| A5 | 30 X testimonials, same standard | NOT MET | None. | As A4 (L). | no |

## Submission requirements and evaluation

| # | Requirement | Status | Evidence | Gap → smallest fix | Cutover? |
|---|---|---|---|---|---|
| SR1 | Public repo with the wallet module, SDK, CLI, both mini-apps and the Basecamp GUI, under MIT **and** Apache-2.0 | MET | `github.com/logos-kit/logos-kit` is public. `LICENSE-MIT` and `LICENSE-APACHE` are present; Cargo and npm say `MIT OR Apache-2.0` (`Cargo.toml:11`, `packages/*/package.json`). | GitHub's license detector shows only Apache-2.0. Harmless; the README states the dual license. | no |
| SR2 | Narrated video: multi-account setup including a private account, faucet funding, send and receive, token use, testimonial connect → select → approve → create | NOT MET | `PROGRESS.md:206` (open). | Record it on the official testnet after the cutover (M). | yes |
| SR3 | Evidence for each adoption criterion (app links and repos, on-chain testimonials with per-month counts, Discord and X links) | NOT MET | Tooling only: the exporter and `adoption/tracker.md`. | Comes with A1–A5. | yes |
| SR4 | FURPS self-assessment in a `solutions/LP-0021.md` PR titled `Solution: LP-0021 — …` | NOT MET | No draft anywhere (`grep FURPS`). | Draft it now from this audit. Include:<br>• the catalog URL;<br>• the program id;<br>• CI run links;<br>• snapshots;<br>• the "template, not fork" note;<br>• the "apps propose public transactions" scope.<br>Effort S; it is filed only once adoption qualifies. At most 3 submissions, 1 per week. | partly |
| SR5 | Evaluators run the demo script unmodified from a clean environment | **PARTIAL** | `e2e/demo.sh`: OS and prerequisite checks with install hints. `--local` builds the sequencer from source (no hosted services); `--preview` uses real proofs. 16/16 and 14/14 on 2026-09-30 per `PROGRESS.md:190` (no log stored). | (a) No `--testnet` mode.<br>(b) `--preview` depends on our single-host sslip.io network, which had a DNS outage (`PROGRESS.md:204`).<br>(c) No token-from-private step.<br>Add `--testnet` after the cutover and the F1 steps; keep a run log under `docs/reviews/` (S). | **yes** |

---

## Status counts

| Status | Count | Rows |
|---|---|---|
| MET | **16** | F1–F5, U1–U3, R1–R4, S2, S3, S5, SR1 |
| PARTIAL | **7** | U4, U5, U6, U7, P1, S4, SR5 |
| BLOCKED-ON-CUTOVER | **4** | F6, F7, F8, S1 |
| NOT MET | **8** | A1–A5, SR2–SR4 |

**Also need the cutover even though not marked blocked:** U3 (new release), U5 (builtins at v0.3.0), U7 (re-check fees), R3 (default network), S3 (re-green CI), S4/S5 (stale text), A1–A3, SR2, SR3, SR5.

## What judges will try in person: quick verdict

| Check | Verdict |
|---|---|
| Approval prompt shows the requesting app | ✅ Name, module id and icon. The "Unsigned app" banner shows even for signed apps. |
| …account, asset, amount, destination | ✅ for native sends, wallet sends and testimonials. ❌ for **token transfers proposed by an app** (U4 bug). |
| …human-readable contract effects | ✅ for native, token, ATA and testimonial calls. ⚠️ Other signers aren't listed. |
| …unlimited-approval flag | ⚠️ LEZ has no allowances. Authority use is flagged and unknown calls need an acknowledgement; there is no explicit "can move everything" wording. |
| …source-verification status | ✅ for token, ATA and testimonial. ❌ No row for native sends. ⚠️ Third-party programs are always "Unverified". ❌ On the testnet, token shows mismatch until the re-pin. |
| Private balance read protection | ✅ An opaque handle per app, plus an explicit tick. |
| Multiple public + private accounts | ✅ |
| Native + token from public and private accounts | ✅ in code and local E2E. ⚠️ No GUI path to obtain a token. ⚠️ No live real-proof token send from a private account. |
| Testimonial fields | ✅ Text, optional username, `LP-0021/logos-kit`, timestamp bounded by the transaction validity window. ⛔ Not on the official zone yet. |
| Basecamp GUI + CLI | ✅ |
| Catalog `logos-repo.json` URL | ✅ Live. ⚠️ The current release targets rc1. |
| Docs with testimonial and faucet worked examples | ✅ Live. ⚠️ Stale "0.2" text. |
| 10 apps / 150 testimonials | ❌ 0 / 0. The clock starts at the cutover. |
| UX for non-experts | ⚠️ Polished, but untested with real users; token flows need the CLI. |

---

## Gaps to close, in priority order

Effort: **S** ≤ 1 day · **M** a few days · **L** substantial or calendar-bound.

1. **Official testnet cutover** (in flight in another session) · **L**.
   - Unblocks F6–F8, S1, A2–A3 and SR5.
   - Steps: re-pin to v0.3.0 `db66590` (the circuit and all program images changed) → `just verify-builtins` → rebuild and immutable-deploy the testimonial program, then add the registry and `TESTIMONIAL_PROGRAMS` entries → testnet faucet backend → testnet as the default → catalog 0.1.4 → docs → §9 real-proof routes → §10 daily evidence snapshots.
   - Also fix the stale `f7fda38` in `pins.md` and `cutover-0.3.md`.
2. **Fix the approval sheet for token transfers proposed by apps** (U4-1) · **S**.
   - Derive the "You send" card from `summary.outflows` for any asset (`ApprovalView.qml:34-40,103-109`).
   - Add a harness step that has an app propose a token transfer.
3. **Make source verification complete** (U5) · **S**.
   - A "built into LEZ" row for native sends.
   - Use `load_cache` in the approval path (`verify.rs:224-226`).
   - A "Source mismatch" label.
   - Show `summary.signers` (U4-2) and "this program can move what these accounts hold" for unknown calls (U4-3).
4. **Start the adoption clock the day the program is live** (A1–A5) · **L**, calendar-bound.
   - Approve and post `adoption/drafts/*`; onboard builders through the template and conformance kit.
   - Aim for ≥ 30 testimonials in the first calendar month, so the earliest claim lands around 2026-12-01.
5. **A GUI token path for judges** (F2/U6) · **M**.
   - A "Create test token" action in the wallet (wrapping the engine's existing `token create`), and/or a demo-token drop from the faucet.
   - Also "Track token by definition".
6. **Evaluator script** (SR5/F1/S3) · **S**.
   - `demo.sh --testnet`.
   - Add token send from a private account and private→private steps to `demo.sh` and `preview-flows.sh`.
   - Add `e2e/tokens.sh` to `e2e.yml`.
   - Store a run log.
7. **Gas and fee display** (U7) · **S**.
   - Estimate = gas limit × base fee (already fetched).
   - "Fee paid" after inclusion.
   - Docs note that the 0.3 RPC doesn't report gas used; re-check on v0.3.0.
8. **README and docs refresh** (S4/S5) · **S**.
   - Remove the "testnet runs 0.2" lines; fix the "CI ⏳ S9" row.
   - Add a numbered Basecamp walkthrough: accounts, private account, send and receive, tokens, connected apps.
9. **Narrated video** on the official testnet, following the spec's checklist (SR2) · **M**.
10. **Draft `solutions/LP-0021.md` with the FURPS self-assessment** (SR4) · **S**.
    - Include the catalog URL, program id, CI links and evidence snapshot paths.
    - Note "template copy, not a fork" and the scope "apps propose public transactions only".
11. **UX validation** (U6/P1) · **M**.
    - 2–3 sessions with non-expert users.
    - Replace the blanket "Unsigned app" banner.
    - Clearer fee-cap copy.
    - Record the performance budgets and the ~4.3 GB proving memory requirement in the docs.
12. **Platform coverage** (S2/U1) · **M**.
    - A Linux Basecamp GUI run; consider a `darwin-x86_64` variant.
    - Run the other-modules pattern once in Basecamp.
13. **Test hardening** (R2) · **S**: assert that a private-balance read is refused before consent.
14. **Optional:** Logos Storage encrypted backup (R4) · **L**. Not required while there is no remote persistence. Also a real domain for the preview network (sslip.io outage) · **S**, but it matters less once the testnet is the default.

## Closed since the audit (2026-10-06, branch `ui/wallet-v3`)

| Row | What changed | Evidence |
|---|---|---|
| F6, F8, S1 | Official testnet cutover. Re-pinned to v0.3.0 `db66590`, testimonial `5YoH3x…fVef` deployed immutably, testnet drip and relay live, testnet is the default network. | Every route proved with real proofs on the official testnet, blocks 11969–12004 (`PROGRESS.md`) |
| A2, SR3 (tooling) | `daily.yml` commits `snapshots/<zone>/<submission>-<date>.json` and the block-scan cache to the `evidence` branch every day. The cutover-issue step is replaced by a warning on the rollback criteria. | First snapshot: 1 distinct author, tip block 12,014 |
| U4 (1) | The outflow is built from `summary.outflows` for any asset. A token transfer an app proposes shows its asset, amount and destination. | `ApprovalView.qml` `outFlow` |
| U4 (2) | Every public signer is listed under technical details, and a warning appears for any signer other than the sending account. | `ApprovalView.qml` `extraSigners` |
| U4 (3) | The unknown-call notice says that the program can move anything the signing accounts hold. | `ApprovalView.qml` |
| U4 (4), U6 (d) | "Unsigned app" shows only for apps without Basecamp's `manifest.sig`. Signed installs read "Installed from a signed package". | `service.rs` `app_info` → `signed`; `Store.appSigned` |
| U7, U6 (c) | The fee at today's base fees (`getFeeState`). It is **exact** for a native transfer, which runs at zero cycles: signed bytes × storage base fee + tip. A program call shows **up to**, pricing its cycles at the gas limit. The cap, gas limit and base fee are under technical details. After inclusion, public native sends show the **fee paid** from the sender's balance. The docs say the 0.3 RPC reports no gas used. | `qa_fees.py`: review 0.000002968 LGO = paid 0.000002968 LGO (local); `tx.rs` `Fee::estimate`; `engine.rs` `fee_paid` |
| U6 (design) | Ledger design across the wallet, both apps and the landing (Refero: Family, Fuse, Phantom, Ctrl). | `docs/design/ledger-*.png` |
