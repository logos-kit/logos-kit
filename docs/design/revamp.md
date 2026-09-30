# UI and docs revamp (2026-09-29)

The maintainer's verdict on the S8 release:
- the docs are mediocre;
- the UI needs revamping;
- 21st.dev was barely used.

This brief governs the revamp across the wallet, the mini-apps, the template, the QML UI kit and the docs site.

## Keep

- **Tray** stays the design language (`docs/design/brand.md`), in light and dark, with the same tokens (`@logos-kit/theme`).
- The reference implementation stays `apps/design-lab`.
- The bar is Family, Porto, Rabby and RainbowKit. It is not the Logos site palette, and not "AI-generic".
- Use real logos (Logos mark, token logos, app icons), never generic glyphs standing in for a brand.

## Change

- **Every component starts from a 21st.dev component.** Pick one from the harvested catalog in `.21st-inbox/<category>/`: previews, `sheet.png` contact sheets and `results.json`. If nothing fits, search again (`npx @21st-dev/cli search … --json`) and pull its code (`npx @21st-dev/cli get <id>`).
  - **On the web** (docs, design lab), install it (`21st add` / shadcn) and restyle it with Tray tokens.
  - **In QML**, port it: the same structure, spacing, motion curves and durations, in Qt Quick. That means `Behavior`, `NumberAnimation`, `SpringAnimation`, `OpacityAnimator`, states and transitions.
  - Record the source in a header comment: `// From 21st.dev <author>/<slug> (id <n>): <url>`.
- **Motion is part of the product.** Every state change gets one:
  - loading → content;
  - approve → proving → signing → included;
  - errors;
  - toasts;
  - sheets.

  Keep it quick: 150–350 ms, ease-out or spring, nothing gratuitous. Respect reduced motion when the platform reports it.
- **States:** every screen has designed loading (skeleton or shimmer, not a spinner alone), empty, error-with-recovery, pending and success states.
- **Density and hierarchy:**
  - one primary action per screen;
  - amounts in large tabular numerals;
  - secondary text in `text2`/`text3`;
  - no raw base units, ids or engine errors without a human line first.

## QML constraints (Basecamp sandbox; see AGENTS.md)

- No network, no remote or `data:` images, and no `Qt.openUrlExternally`.
- Canvas may not paint, so build with Rectangles, Shapes, gradients and bundled SVG or PNG assets.
- The JS is Qt 6.9 V4: no BigInt, no `Intl`, no regex named groups or lookbehind, and `short` is reserved.
- Plain text only for untrusted strings.
- Everything must render in the dev harness (`modules/logos_kit_wallet_ui/dev/harness.py`, `app_harness.py`) and in real Basecamp.

## Component map (the minimum set)

| Need | 21st category to start from |
|---|---|
| Skeleton + shimmer loaders, shimmer text ("Proving…") | `loaders` |
| Proving and transaction pipeline (steps with state, elapsed time) | `progress` (staged pipeline, status timeline) |
| Progress ring (proof progress, countdown) | `progress` |
| Toast stack (success, error, info; stacked, swipe or auto-dismiss) | `toasts` |
| Sheet / dialog / confirmation (spring in, scrim) | `dialogs` |
| Empty state, error card with retry, success check animation | `feedback` |
| Animated balance / number ticker; amount input with max | `numbers` |
| Address chip with copy (morph to a check) | `address` |
| QR card | `qr` |
| Onboarding steps, recovery phrase grid and confirm | `onboarding` |
| Password strength, OTP/PIN, segmented control, switch, search | `inputs` |
| Token list rows (with logos), account switcher, activity feed, connect modal | `wallet` |
| Badges, tooltips, settings list, dropdown | `misc` |

## Deliverables

1. **The kit.** `sdk/qml/LogosKitUi/` v2 with the components above, each with a source comment, plus a QML gallery page (`sdk/qml/gallery/`) screenshotted in light and dark to `docs/reviews/revamp/kit/`.
2. **The screens.** The wallet UI, both mini-apps and the template are rebuilt on the kit, with fresh screenshots of every state.
3. **The docs.** A rewrite to wagmi/RainbowKit quality: the IA, landing, guides, API reference, crisp current screenshots and live demos. The README is rewritten too.
