# Prompt for an independent Codex review of the whole project (S0 → first release)

Open Codex in `/Users/abu/dev/hackathon/logo-tech/logos-kit` and paste everything below the line.

---

You are an independent senior reviewer: product, engineering and design. An AI agent built this project over several sessions and has just shipped a "first release". **Be skeptical.** Find what's wrong, missing, half-done or quietly dropped. Don't confirm the agent's story. Read the code and the live artifacts, not just `PROGRESS.md` or commit messages.

For every claim:
- cite `file:line`, a URL or a command;
- label it **verified** (you read it or ran it), **inferred** or **unknown**;
- never invent facts. If you can't check something, say so.

The maintainer's own words, which you should hold the work to:

> "Review from start to finish … make sure you're not forgetting any features. The docs are mediocre. The UI needs revamping. 21st.dev wasn't used as much as it could have been. I don't like some of the design. This is a wallet application."

## 1. Context

- **What it is:**
  - **Logos Kit**, an entry for Logos λPrize **LP-0021 "LEZ Wallet and Provider SDK"** ($20k).
  - There's no fixed deadline. The prize goes to the first entry that meets it, and adoption must be sustained for at least 2 months.
  - A competitor started on 2026-09-25.
- **Pieces:**
  - a Rust wallet engine (`crates/wallet-engine`) and CLI (`crates/logos-kit-cli`);
  - a Basecamp core module and a QML wallet UI (`modules/logos_kit_wallet*`);
  - the testimonial and faucet mini-apps (`modules/logos_kit_testimonial`, `modules/logos_kit_faucet`);
  - a QML SDK (`sdk/qml/LogosKit`) and a QML UI kit (`sdk/qml/LogosKitUi`);
  - TypeScript packages (`protocol`, `packages/{codec,client,theme,qml-bundle}`);
  - the testimonial program (`programs/testimonial`);
  - a dApp template (`templates/basecamp-dapp`);
  - a conformance kit (`modules/logos_kit_wallet_fake`);
  - a Fumadocs docs site (`apps/docs`);
  - a design lab (`apps/design-lab`);
  - a self-hosted faucet (`crates/logos-kit-drip`);
  - deploy files (`deploy/preview-net`).
- **Where the network stands:** the official LEZ testnet still runs **0.2**. The wallet is built on LEZ **v0.3.0-rc1**, so it runs on its own public **preview network** until the official testnet moves to 0.3:
  - RPC: `https://lez.84.46.247.92.sslip.io`
  - faucet: `https://lez-drip.84.46.247.92.sslip.io`
- **Live artifacts to check:**
  - docs: `https://logos-kit-docs.vercel.app`;
  - catalog: `https://github.com/logos-kit/logos-kit-modules`, holding wallet core and UI 0.1.2 and the testimonial and faucet apps 0.1.0;
  - preview-net binaries: the GitHub release `preview-net-v0.1.0`.
- **History:** `git log --oneline main`. The stages are S0–S8 in `docs/dev/PLAN.md`. S9–S18 come later (CI, React, React Native, passkeys, submission).

## 2. The requirements. Read all of these first.

1. **The prize:** `../refs/lambda-prize/prizes/LP-0021.md`, in full. It's the ground truth. Note especially:
   - the functionality list;
   - the Wallet Provider SDK and the selection and approval flow;
   - Usability;
   - Supportability (a README with setup, account management, CLI and Basecamp usage; docs with **both mini-apps as worked examples**);
   - the narrated demo, covering the private, token and testimonial paths;
   - the E2E test in CI against a real sequencer;
   - the Adoption rules: 150 on-chain testimonials that clearly name this wallet, from distinct accounts with prior activity, at least 30 per month for 2 months, plus 10 independent Basecamp developers, 30 Discord and 30 X testimonials.
2. **Our readings of the prize:** `../docs/01-prize-LP0021.md`, `../docs/10-decisions-and-ecosystem.md` (the user's confirmed decisions) and `../docs/11-codex-independent-review.md` (an earlier Codex review; check its adopted findings are actually implemented).
3. **What the maintainer wants the product to be:** `../docs/07-product-vision-handoff.md`, which describes a wagmi/RainbowKit-grade connect kit and SDK with premium UI and wagmi-grade docs with live demos. It is inspired by their KasFlow.
4. **The architecture and the first-release definition:** `../docs/09-architecture.md`, especially **§8 (first-release milestone)** and §9.
5. **The plan:** `docs/dev/PLAN.md`:
   - the **Rules** at the top;
   - **every stage S0–S8**;
   - "Basecamp / QML architecture";
   - "Integration-confidence tests";
   - "Inputs needed from the user";
   - the S9–S18 sections, only to judge what's deferred versus forgotten.
6. **Repo and design rules:** `AGENTS.md`, `docs/design/brand.md` (the "Tray" design, light and dark) and `docs/design/ux-spec.md` if present.
7. **The maintainer's standing rules** (from memory, paraphrased):
   - Working functionality is the deliverable, not tests. Loading, pending, empty, error and recovery states are first-class.
   - **Every UI component starts from 21st.dev.** Search the catalog and use the best author component before hand-writing one. For QML, convert the 21st design into QML.
   - Use real brand and token logos, not generic icon glyphs.
   - Take colour and design cues from RainbowKit, wagmi, Privy, Porto, Rabby and Family, **not** from the Logos site.
   - The docs are Next.js (Fumadocs) and must not look like slop. Model them on the big kits' docs.
   - Check Context7 or the library's docs before using a library.
   - Everything must be publishable: a clean monorepo, packages, CI.
8. **What the agent claims is done:** `PROGRESS.md` (every stage) and the earlier reviews in `docs/reviews/*/`. Treat these as claims to check, not facts.

Reference implementations to judge the UI and docs against are cloned under `../refs/connect-kits/`:
- `evm/rainbowkit`, `evm/connectkit`, `evm/appkit`, `evm/onchainkit`;
- `multichain/*`, `solana/*`, `passkeys/*`;
- the notes in `_notes/`.

## 3. What to do

### A. Feature coverage: the most important part

Build one table covering all of the following, and mark each row **done / partial / missing / deferred-with-reason / dropped-without-reason**, with evidence:
- **every** LP-0021 requirement, one row each;
- **every** item in the doc 09 §8 first-release milestone;
- **every** bullet in PLAN.md S0–S8;
- every decision in doc 10 that affects the product.

Call out anything the plan or the prize requires that nobody mentions any more. Check at least:
- **Wallet functionality:**
  - native and fungible-token send and receive, in public and private accounts;
  - multiple accounts, with create, label and switch;
  - restore and backup;
  - auto-lock;
  - keys surviving a restart or network drop;
  - gas estimate and gas used on the approval and status screens;
  - program source verification shown on approval.
- **The SDK:**
  - access requests, reads, and transfer and contract-call proposals;
  - selecting a wallet and account;
  - approving with app, account, asset, amount, destination and effects shown;
  - no signing, submission or private read without a grant;
  - wallet selection when several wallets exist.
- **The mini-apps:** exactly as LP-0021 describes them (text, username, submission id; account selection, success and failure, rate limits).
- **Supportability:**
  - Does the README (the repo root one, not just the docs site) cover setup, account management, step-by-step CLI and Basecamp usage, zone config, and local module build instructions with loadable assets?
  - Is there a narrated demo?
  - Is there an E2E test in **green CI on the default branch**? Check `.github/workflows/`, and whether they exist at all.
- **Adoption readiness:**
  - the evidence exporter;
  - testimonial counting on the official network (the preview network does **not** count);
  - `adoption/` tracker and drafts;
  - what blocks the 2-month clock from starting.
- **The preview network:** is it a sound stand-in, and what exactly has to happen on the day the official testnet flips to 0.3? Is that written down?
- **Deferred work (React, React Native, passkeys, embedded wallet):** is it clearly scoped and not silently lost?

### B. UI and design review: be critical, the maintainer is unhappy with it

Look at the actual screens:
- the screenshots in `docs/reviews/s7/`, `docs/reviews/s8/**` and `docs/reviews/s7/catalog/`;
- the QML in `modules/logos_kit_wallet_ui/qml/**`, `modules/logos_kit_testimonial/qml/Main.qml`, `modules/logos_kit_faucet/qml/Main.qml`, `templates/basecamp-dapp/qml/Main.qml`, and `sdk/qml/LogosKitUi/*`;
- if you can, run `just qt-setup` and the dev harness, `modules/logos_kit_wallet_ui/dev/harness.py`.

1. Compare with RainbowKit, ConnectKit, AppKit, Privy, Rabby, Porto and Family: connect modal, account picker, approval sheet, transaction status, toasts, empty and loading states, and motion. Where does ours look amateur, dated or "AI-generic"? Be specific: spacing, hierarchy, type scale, colour, icon use, motion, density, copy.
2. **21st.dev usage.** For each screen and component, say whether it's derived from a 21st.dev (or other premium-registry) component, or hand-written. List the components a premium wallet needs that are missing or weak:
   - skeleton and shimmer loaders;
   - progress and step indicators for proving;
   - toasts;
   - dialogs, sheets and pop-overs;
   - an animated number or balance;
   - an account switcher;
   - an amount input with max;
   - a token list with logos;
   - an address chip with copy;
   - QR;
   - an activity feed;
   - an error recovery card;
   - onboarding;
   - seed phrase reveal and confirm;
   - password strength.

   For each missing one, suggest what kind of 21st.dev component to base it on, and whether it's feasible in QML under the sandbox rules (no network, no `data:` images, Canvas may not paint, Qt 6.9 V4 JS).
3. Consistency across the wallet, the two apps, the template and the design lab (`apps/design-lab`, the reference Tray implementation). Where do they drift from `docs/design/brand.md`?
4. Accessibility: contrast in light and dark, focus order, keyboard use, text scaling.
5. UX copy: is it clear to a non-expert? List confusing strings. Are raw base units, ids or technical errors shown to users?

### C. Docs review: the maintainer called them "mediocre"

Review `https://logos-kit-docs.vercel.app` and `apps/docs/**` against the wagmi, RainbowKit, Privy and Porto docs (their sources are under `../refs/connect-kits/`).

1. The information architecture: can a developer go from zero to a working Basecamp dApp in 10 minutes? What's missing:
   - installation;
   - concepts (zones, public versus private accounts, proving time, grants);
   - a guide per task;
   - an API reference per function with types;
   - troubleshooting;
   - FAQ;
   - migration notes;
   - examples;
   - a changelog.
2. The landing page and visual quality: screenshots (are they real, current, crisp and consistent?), live demos, code blocks, diagrams. What looks cheap?
3. Accuracy: every method, parameter, error code and behaviour claimed must match the code. List each mismatch.
4. Completeness against LP-0021 Supportability, and against PLAN S8's docs features:
   - twoslash;
   - `fumadocs-typescript`;
   - `llms.txt`;
   - `.md` routes;
   - search;
   - the "other Logos modules" example;
   - the security model;
   - `context7.json`;
   - `AGENTS.md`.
5. The README at the repo root: is it what an evaluator needs?

### D. Correctness and security, briefly

Only report **new** findings: see "Already fixed" below.
- **Stuck or racy state machines:** in the apps and the wallet UI.
- **Wallet engine:**
  - the policy authority (`policy.rs`);
  - approval binding (`tx.rs`, `engine.rs`);
  - the new testimonial re-page at signing (`tx.rs` `repage`);
  - `ui_appInfo` (`service.rs` `app_info` / `icon_grid`: path traversal, decompression bombs, size limits);
  - `lez_openExplorer`.
- **The drip faucet (`crates/logos-kit-drip`):**
  - draining;
  - `X-Forwarded-For` trust;
  - request-key reuse;
  - `Retry-After`.
- **The preview deployment (`deploy/preview-net`):**
  - the key handling in `entrypoint.sh`;
  - the unauthenticated RPC behind Traefik;
  - the rate limits;
  - the genesis;
  - anything that would let a stranger halt or drain it.
- **Secrets:** anything committed that shouldn't be (keys, tokens, `.env`). Search the whole history: `git log -p | grep -iE "key|secret|token"`, with judgement.

### E. Evidence: run what you can, and report the output as it is

```sh
pnpm install && pnpm build && pnpm check:types
cargo clippy --workspace --all-targets -- -D warnings && cargo test -p wallet-engine --lib
(cd apps/docs && pnpm build)
python3 scripts/capability-matrix.py --check
cargo xtask fingerprint https://lez.84.46.247.92.sslip.io     # expect version 0.3
cargo xtask fingerprint https://testnet.lez.logos.co          # official testnet version today
curl -s https://lez-drip.84.46.247.92.sslip.io/               # drip info
e2e/preview-flows.sh --tokens-only                            # live network, ~10 min, real proof
```

Don't run `e2e/standalone.sh` if something already answers on port 3040.

## 4. Already fixed or known. Don't re-report unless you have new facts.

- **From the S8 Codex review (`docs/reviews/s8/codex-review.md`), bugs 1–7 are fixed.** Verify the fixes if you like, in `438e2cc` and `26e3cd0`:
  - the page race;
  - the account switch in flight;
  - faucet "checking" forever;
  - the private claim watching the wrong account;
  - Done on an unknown outcome;
  - network epochs;
  - the late result.
- **Also fixed:**
  - the conformance kit exists (`75dbd42`);
  - twoslash and type tables exist (`4f35a7b`);
  - the approval fee label is correct: native LEZ has no decimals.
- **Deliberately deferred:**
  - the testimonial program on the **official** testnet, until it runs 0.3;
  - the S9 CI workflows;
  - React, React Native and passkeys (S10–S15);
  - demo recordings and usability sessions, which need people.

  Say whether each deferral is *safe* for the prize, and whether anything is deferred without a plan.

## 5. Output

Write your review to **`docs/reviews/full-1/codex-review.md`**:

1. Summary verdict: how far from a prize-winning submission, in plain words.
2. The feature coverage table (section A), grouped by source.
3. **Forgotten or dropped features**, ranked by prize impact.
4. The UI and design review (B), with a prioritised redesign list: screen, problem, 21st.dev-style component to base the fix on, and QML feasibility.
5. The docs review (C), with a prioritised rewrite list and a proposed information architecture.
6. Correctness and security findings (D), ranked critical / high / medium / low, each with `file:line`, a failure scenario and a fix.
7. The evidence you ran, and the output (E).
8. The top 15 next actions, in order, each with the expected effort (S / M / L).

Be blunt and specific: "the approval sheet's fee row is 12 px grey on grey", not "improve contrast". **Don't edit any other file**, and don't commit, push, deploy or release anything.
