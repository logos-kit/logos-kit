# Revamp picks: 21st.dev sources for LogosKitUi v2

Every v2 component in `sdk/qml/LogosKitUi/` is ported from a 21st.dev component: its structure, spacing and motion curves and durations, rebuilt in Qt Quick with Tray tokens. Each file names its source in a header comment.

Candidates were compared from the contact sheets in `.21st-inbox/<category>/sheet.png`. The chosen components' code was read with `npx @21st-dev/cli get <id>` and is saved in `.21st-inbox/code/<id>.txt`, which is gitignored.

| QML component | 21st.dev source (id) | Why this one | What was taken |
|---|---|---|---|
| `Pipeline.qml` | rmahammad/processing-timeline (29371) | The only candidate modelling one item through app-owned stages, with honest status. That's exactly approve → prove → sign → submit → included | 2 px rail filled when travelled; 2 px ring nodes; active node pulse (scale 1 → 1.7, opacity 0.5 → 0, 1.4 s); rows rise 8 px in 260 ms on `[0.2, 0, 0, 1]`; 6 px progress bar; "presentation only, never fakes progress" |
| `Stepper.qml` | corr/stepper (28565) | Clean numbered steps, no chrome | Check on done steps, filled current step, connector fill |
| `ToastHost.qml`, `Toast.qml` | cnippet-dev/toast (24297, Sonner stack); framecn/toast-notification (19994, spring-in) | Sonner's stack is the reference toast UX | Stack index scale −6% (Sonner uses −10%) and 10 px peek; expand on hover; 500 ms on `[0.22, 1, 0.36, 1]`; enter from below; auto-dismiss paused on hover; swipe to dismiss; icon disc by tone |
| `Sheet.qml` | animbits/magnetic-drawer (19360); wensity/drawer (31360) | A physical bottom sheet matching the wallet's Tray sheet language | Spring stiffness 300 / damping 30 → `SpringAnimation` 4.2/0.36; drag to dismiss past 25% or on a flick; handle bar; scrim |
| `Dialog.qml` | ai2/alert-dialog-layout (28277); originui/alert-dialog (1144) | A compact confirmation with an icon | Icon disc, title, message, two equal buttons; 0.96 → 1 scale with fade, 200 ms |
| `Popover.qml`, `AccountSwitcher.qml` | originui/dropdown-menu (385); coss.com/menu (11561) | Dense, legible menu rows | Scale from the top edge 0.96 → 1, 150 ms; 14 px row radius; check on the selected row; divider plus footer action |
| `Tooltip.qml` | wensity/tooltip (31328) | Short delay, inverted surface | 400 ms delay, 150 ms fade and scale, inverted colours |
| `ShimmerText.qml` | mona_biasia/gradient-shimmer (16788) | The "live label" treatment for Proving… and Checking… | 1.45 s linear sweep. Masking isn't available in the sandbox, so each glyph is coloured by its distance from the sweep |
| `Skeleton.qml`, `SkeletonCard.qml` | animbits/loaders-skeleton (19999); jshguo/skeleton (11894) | Layout-matched placeholders | Moving highlight; row, balance, card and lines variants shaped like the real content |
| `Dots.qml` | loading-ui/dots (19935) | A quiet "waiting on someone else" state | Three dots, 160 ms stagger, rise with fade |
| `ProgressRing.qml`, `ProgressBar.qml` | edwinvakayil/progress (26542); diceui/circular-progress (24462) | Spring-smoothed value | Ring and bar spring toward the value; indeterminate spin and slide; centre slot |
| `SuccessCheck.qml` | arihantcodes/task-checkbox (29942); ruixen.ui/success-login-card (7976) | A done moment worth seeing | Disc springs in; the check draws in two strokes (140 + 220 ms); a one-time ring burst |
| `EmptyState.qml` | laziekiki/empty-state-kit (27024); uiable/empty-background (18266) | Calm, not cartoonish | Glyph tile in faint concentric rings, title, one line, optional action |
| `ErrorCard.qml` | olewandowski1/error-empty-state (19376); serafimcloud/error-message (12393) | Recovery-first error | Human title and body; Retry as the primary action; the raw error behind "Details" |
| `NumberTicker.qml` | soralabs/number-flow (28181); unlumen/animate-digits (20071) | The Family / Robinhood balance roll | Odometer digit columns, 900 ms on `[0.16, 1, 0.3, 1]`; only changed digits move; widths ease between digits |
| `AmountField.qml` | cnippet-dev/currency-amount-input-group (28357) | Structure. The layout follows Family and Rabby sends | Big centred figure that shrinks to fit; token chip; "Balance · Max"; shake on invalid |
| `AddressChip.qml` | cubby-ui/copy-button (27896); ddoemonn/copy-button (23529) | Icon morph without text churn | Copy → check morph (scale, rotate, fade, 150 ms); resets after 1.5 s |
| `QrCard.qml` | tom_ui/qr-code (12249) | Rounded finders and dot modules look premium; square QR looked dated | Rounded finder patterns, dot data modules, centre mark (Logos) on EC level M |
| `SegmentedControl.qml` | ddoemonn/segmented-control (23552); micka_design/segmented-tabs (26923) | A snappy spring pill | Sliding pill (stiffness 520 / damping 34 / mass 0.45 → `SpringAnimation` 6/0.42); arrow keys |
| `Toggle.qml` | micka_design/switch (10334); serafimcloud/switch (21948) | Tactile | The thumb stretches while pressed; spring-eased travel |
| `PasswordStrength.qml` | ddoemonn/password-strength (23542) | Segmented bars plus a checklist | Four bars filling on a spring; live requirement checks |
| `PhraseGrid.qml` | diarmuradi/recovery-code (29244), laid out like Family and Rabby | Numbered, hidden-by-default phrase | Numbered cells, reveal veil, confirm blanks |
| `Badge.qml` | diceui/status (25395) | A live status dot | Pulsing dot (scale 1 → 2.3, 1.2 s) for connected and syncing |
| `TokenRow.qml`, `SettingsRow.qml` | sean0205/item-action-list (28284); shadcnspace/notification-settings-field (26523) | Row anatomy | Leading tile, two-line text, trailing slot, hover tint |
| `ActivityRow.qml` | hari/transaction-list (2943); felipemenezes098/activity-feed (29394) | Compact, readable feed | Direction disc, signed coloured amount, status line; pending pulse and dots; failed struck through |
| `BalanceCard.qml`, `ActionTile.qml` | beratberkayg/wallet-card-2 (5214) | Balance, hide toggle and actions | Label with an eye toggle, the rolling figure, a private line, round quick actions |

Kept and upgraded:
- `Btn` gains a hover sheen and a focus ring.
- `Card` gains a light-mode shadow.
- `Glyph` gains search, clock, wallet, inbox, zap, key, swap and message.
- `Theme` gains the v2 motion tokens (`emph`, `expoOut`, `sonner`, `dFast`/`dBase`/`dSlow`/`dNumber`) and elevation (`shadow`, `raised`).

## Not ported, and why

- **Blur and glass** (the backdrop blur in several drawers and modals): `MultiEffect` isn't guaranteed in the Basecamp sandbox. We use solid raised surfaces, a scrim and `Shadow.qml`, which fakes elevation with stacked translucent rects.
- **Gradient text masks** (the gradient shimmer in its original form): no masking without effects. It's approximated per glyph in `ShimmerText`.
- **The wallet dashboards and charts** in the "wallet" results (stock and crypto dashboards, candles): not wallet UX for LEZ, and they need Canvas.
- **The connect-wallet modal** (ravikatiyar162/connect-wallet-modal, 8588): generic list-of-wallets styling. Basecamp's own chooser picks the wallet, and our connect sheet is built from `Sheet` plus `AccountSwitcher`-style rows instead.
