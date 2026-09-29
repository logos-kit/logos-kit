# LogosKitUi

Tray-styled QML components (the Logos Kit wallet's look) for Basecamp apps.
Copy this folder next to `LogosKit/` in your `ui_qml` module and
`import "LogosKitUi"`. It reads colours from `LogosKit/Tokens.js`.

v2 components are ported from 21st.dev components (sources in each file and in
`docs/design/revamp-picks.md`). The gallery shows them all:
`python3 sdk/qml/gallery/shoot.py` (screenshots in `docs/reviews/revamp/kit/`).

| Component | What it is |
|---|---|
| `Theme` | singleton: colours, radii, font (bundled Onest), motion (`emph`, `expoOut`, `sonner`, `dFast…dNumber`), elevation; `Theme.dark`, `Theme.reducedMotion` |
| `Txt` | text, plain by default (never renders untrusted rich text) |
| `Btn`, `IconButton` | pill button (`ink`, `action`, `private`, `neutral`, `ghost`, `danger`; `busy`, `armDelay`), round icon button |
| `Card`, `Shadow`, `InfoRow`, `Notice`, `Tag`, `Badge` | surfaces and elevation, label/value rows, inline notes, status tags, live status pill |
| `Field`, `TextBox`, `AmountField` | inputs; `TextBox.maxBytes` counts UTF-8 bytes; big send-amount entry with token chip and Max |
| `Spinner`, `Dots`, `Skeleton`, `SkeletonCard`, `ShimmerText` | pending and loading states |
| `ProgressBar`, `ProgressRing`, `Pipeline`, `Stepper` | progress, proving/transaction stages, multi-step flows |
| `SuccessCheck`, `EmptyState`, `ErrorCard` | done, empty and error-with-recovery states |
| `ToastHost` / `Toast`, `Sheet`, `Dialog`, `Popover`, `Tooltip` | overlays |
| `SegmentedControl`, `Toggle`, `PasswordStrength`, `PhraseGrid` | controls and onboarding |
| `NumberTicker`, `BalanceCard`, `ActionTile`, `TokenIcon`, `TokenRow`, `ActivityRow`, `AccountSwitcher`, `AddressChip`, `QrCard`, `SettingsRow` | wallet building blocks |
| `Identicon`, `LogosMark`, `Glyph` | account avatar, the official Logos mark, line glyphs (Lucide) |

Onest is SIL OFL 1.1 (`fonts/OFL.txt`); glyph paths are Lucide (ISC); the QR
encoder is Project Nayuki's (MIT, `qrcodegen.js`).
