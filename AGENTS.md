# AGENTS.md

Guidance for AI agents and contributors working in this repo.

## Start here
1. Read `PROGRESS.md`. It tells you the current stage and the next action.
2. Read that stage's section in `docs/dev/PLAN.md`.
3. `docs/dev/pins.md` holds every pinned revision. Don't bump a pin without recording why.

## Rules
- **The LP-0021 success criteria gate every stage.** Everything else is additive and must never block them.
- **Tests are not a deliverable.** Write tests only to confirm complex integrations (the list is in the plan). No UI tests.
- **UI:**
  - Web/RN components come from 21st.dev first (`21st search` / `get` / `add`).
  - Use real brand and token logos, not generic icons.
  - Colours follow `@logos-kit/theme`, not Logos' site palette.
  - Loading, pending, empty, error and recovery states are required.
- **Libraries:** check the library's docs (Context7) before first use. Don't guess APIs.
- **Security:**
  - Keys, grants and approvals live only in the wallet engine.
  - Render untrusted strings as plain text (QML `textFormat: Text.PlainText`).
  - Events never carry private data.
- **QML sandbox:** no network; no remote or `data:` images; `Qt.openUrlExternally` is blocked; Canvas may not paint. Details: plan § "Basecamp / QML architecture".
- **Shared TS packages that also run in QML** (`protocol`, `codec` root, `client`, `core`, `theme`) must avoid native BigInt, regex named groups, lookbehind, the `s` flag, core-js and `Intl`.
- **Nothing is pushed, published or deployed** without the maintainer's go-ahead.

## Naming
- npm `@logos-kit/*`
- Basecamp modules `logos_kit_*`
- CLI `logos-kit`
- Never reuse official module names (`lez_core`, `lez_wallet_ui`, `lez_faucet`, `lez_faucet_ui`).
