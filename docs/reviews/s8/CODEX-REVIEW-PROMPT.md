# Prompt for an independent Codex review of S8

Copy everything below the line into Codex, running in `/Users/abu/dev/hackathon/logo-tech/logos-kit`.

---

You are an independent senior reviewer. Another AI agent built stage S8 of this project in one session and says it's mostly done. **Be skeptical.** Your job is to find what's wrong, what's missing and what was quietly skipped, not to confirm the agent's summary. Read the code, not just the commit messages or `PROGRESS.md`. Cite `file:line` for every claim and label it **verified** (you read or ran it), **inferred** or **unknown**. Don't invent facts. If you can't check something, say so.

## Context

- The project: **Logos Kit**, an entry for Logos λPrize **LP-0021 "LEZ Wallet and Provider SDK"**. It includes a Rust wallet engine, a Basecamp core module + QML wallet UI, a QML SDK for third-party Basecamp apps, TypeScript packages, and a CLI.
- The work under review is branch **`stage/08-apps`**, 7 commits on top of `main`:
  ```sh
  git log --oneline main..stage/08-apps
  git diff main...stage/08-apps --stat
  ```
- S8 is the "first release" stage, the one that starts the prize's adoption clock. It covers the testimonial and faucet mini-apps, a dApp template, a conformance kit and the first docs.

## Read these first (the requirements)

1. `../refs/lambda-prize/prizes/LP-0021.md`, in full. Pay attention to the **testimonial mini-app**, **faucet mini-app**, **Wallet Provider SDK**, **selection & approval flow**, **Usability** and **Supportability** (docs must cover both mini-apps as worked examples), and the **Adoption** rules (150 testimonials that clearly name this wallet, distinct accounts with prior activity, 30+ per month over 2 months).
2. `docs/dev/PLAN.md`: the **Rules** near the top, the section **"S8 · Mini-apps + dApp template + conformance kit + minimal docs"**, the **"Basecamp / QML architecture"** section, **"Integration-confidence tests"**, and **"Inputs needed from the user"**.
3. `../docs/09-architecture.md` **§8**: the **first-release milestone** list.
4. `AGENTS.md` (repo rules: security, the QML sandbox, the QML-safe JS subset, naming), and `docs/design/brand.md` (the Tray design).
5. `PROGRESS.md`, the **S8** section. This is the agent's own claim of what's done. Treat it as a claim to check, not a fact.

## What was built (per the agent; verify all of it)

- `modules/logos_kit_testimonial/` and `modules/logos_kit_faucet/`: `ui_qml` apps (`qml/Main.qml`, `metadata.json`, `flake.nix`, `dev/qa_*.py`).
- `templates/basecamp-dapp/`: a `nix flake init -t .#dapp` template whose wallet contract is vendored through `dependency_overrides`. `flake.nix` has `templates.dapp`.
- `sdk/qml/LogosKit/LogosKit.qml`: now follows the wallet's network. `sdk/qml/LogosKitUi/` is a new component kit, copied into apps by `just qml-vendor`.
- New LWS-0 methods **`lez_openExplorer`** and **`lez_chainId`**, wired through `protocol/src/schema/*`, `protocol/schema/*.json`, `modules/logos_kit_wallet/logos_kit_wallet.lidl`, `modules/logos_kit_wallet/rust-lib/src/lib.rs`, `crates/wallet-engine/src/service.rs`, `packages/client/src/actions/wallet.ts` and `packages/qml-bundle/src/facade.ts`.
- Testimonial reads: `packages/codec/src/programs.ts` (`decodeTestimonial`, `decodeTestimonialStats`, `TESTIMONIAL_PROGRAMS`) and `packages/client/src/actions/node.ts` (`readTestimonials`).
- Engine and wallet UI fixes in `crates/wallet-engine/src/service.rs`:
  - the local faucet is cached per sequencer, with a 60 s window;
  - `ui_requestFunds` resolves an app's `pvt_…` handle.

  And in `modules/logos_kit_wallet_ui/qml/Main.qml` and `.../LogosKitWallet/IntentView.qml`:
  - an answered request stays on screen until Done;
  - a pending approval shows after a sheet closes.
- The dev harness `modules/logos_kit_wallet_ui/dev/app_harness.py`, and the e2e scripts `e2e/{testimonial,faucet,template}-app.sh` and `e2e/basecamp-apps.sh` with `tests/apps-flow.mjs` and `tests/bc-lib.mjs`.
- `apps/docs/`: a Fumadocs site. `scripts/gen-reference.mjs` generates the method reference; the pages live in `content/docs/**`.

## What we want from you

1. **Plan coverage: did anything get forgotten?** This is the most important part. Build a table of **every bullet** in PLAN.md's S8 section, **every item** in doc 09 §8's first-release milestone, and every LP-0021 criterion that S8 touches. Mark each one **done / partial / missing / deferred**, with evidence (code path, or a command you ran). Check specifically:
   - Testimonial app: "retries on `index==count` races", the "activity nudge", "text prefilled and validated so it names the wallet", the explorer link.
   - Faucet app: "outcome-unknown checking…", the "private shield step", the rate-limit countdown, clear success/failure reporting.
   - Template: "demos the in-flow faucet and the receipt callback".
   - Conformance kit (`logos_kit_wallet_fake`, a capability matrix from the schema, `just conformance <dapp>`): the agent says it isn't started. Confirm, and say how much it matters for the prize.
   - Docs: the plan lists twoslash, `fumadocs-typescript`, `llms.txt`/`llms-full.txt`, `.md` routes, Orama static search, an LWS-0 reference, a QML quickstart, both worked examples, the "other Logos modules" example, the security/threat model, `context7.json` and `AGENTS.md`. List which are really there.
   - Milestone exit: demo takes, usability sessions, the Codex milestone review.
   - Anything the PLAN's Rules require that S8 skipped (loading/pending/empty/error/recovery states on every screen, 21st.dev for web UI, real logos, Context7 before libraries, publishability).
2. **Correctness bugs.** Read `modules/logos_kit_testimonial/qml/Main.qml`, `modules/logos_kit_faucet/qml/Main.qml`, `templates/basecamp-dapp/qml/Main.qml` and `sdk/qml/LogosKit/LogosKit.qml` closely. Look for state machines that can get stuck (`phase` never leaving `approving`/`pending`/`checking`), races when `kit.api` is rebuilt mid-flow after a network change, watchers not stopped, timers left running, wrong lifecycle or outcome handling, off-by-one or unit errors in amounts and byte limits, and validation that differs from `programs/testimonial/core/src/lib.rs` (`check_text`, `check_username`).
3. **Security.**
   - `lez_openExplorer`: URL construction, input validation, the rate limit, can an app abuse it?
   - `lez_chainId`: is disclosing the network to any caller fine?
   - The `pvt_…` handle resolution in `ui_requestFunds`: can one app resolve or fund through another app's handle? Is `requester` trustworthy on that path?
   - The cached local faucet: is it keyed correctly, and is it only for loopback?
   - The IntentView change (`shown`/`cur`): can a stale request be approved or answered twice?
   - Untrusted text rendered as rich text anywhere (feeds, usernames, faucet reasons).
   - The docs page's `dangerouslySetInnerHTML`.
4. **QML runtime compatibility.** Basecamp runs Qt 6.9 V4 JS in a sandbox. Flag anything that would break there: reserved words, regex features, ES features beyond what `AGENTS.md` allows, remote or `data:` images, `Qt.openUrlExternally`, and relative asset paths inside components.
5. **Tests and evidence.** Are the e2e scripts real proofs or can they pass vacuously? Check the QA scripts for waits that accept the wrong state, and assertions that are missing. If you can, run:
   ```sh
   e2e/standalone.sh && e2e/testimonial-app.sh; e2e/faucet-app.sh; e2e/template-app.sh; e2e/standalone.sh stop
   (cd apps/docs && pnpm build)
   pnpm check:types && cargo clippy -p wallet-engine -- -D warnings
   ```
   Report the results as they are, including failures.
6. **Docs accuracy.** Every API call, method name, error code and behaviour claimed in `apps/docs/content/docs/**` must match the code. List each mismatch.
7. **Things missing entirely** that a third-party developer or a prize evaluator would hit first.

## Already known (don't re-report unless you have new facts)

- The wallet approval sheet shows the fee in base units labelled "LEZ" ("≤ 134,400,000 LEZ").
- The wallet shows two-letter initials ("LO") instead of the app's icon, and so does Basecamp's sidebar for lgpm-installed modules.
- `e2e/template-app.sh` stalled once at the approval step in 4 runs.
- The catalog release (core 0.1.2, UI 0.1.2, apps 0.1.0) and the testnet deploy of the testimonial program are deliberately held until testnet 0.3 is live.
- The docs site isn't deployed (the domain is undecided).

## Output

Write your review to **`docs/reviews/s8/codex-review.md`** with these sections:

1. Summary verdict
2. Plan coverage table (S8 bullets · first-release milestone · LP-0021 criteria)
3. Bugs, ranked by severity (critical / high / medium / low), each with `file:line`, a concrete failure scenario and a suggested fix
4. Security findings
5. QML compatibility
6. Tests and evidence (including what you ran and the output)
7. Docs mismatches
8. Missing entirely
9. Recommended next steps, in order

Be blunt and specific. **Don't edit any other file** and don't commit, push or release anything.
