# LogosKitUi

Tray-styled QML components (the Logos Kit wallet's look) for Basecamp apps.
Copy this folder next to `LogosKit/` in your `ui_qml` module and
`import "LogosKitUi"`. It reads colours from `LogosKit/Tokens.js`.

| Component | What it is |
|---|---|
| `Theme` | singleton: colours, radii, font (bundled Onest), motion; `Theme.dark` |
| `Txt` | text, plain by default (never renders untrusted rich text) |
| `Btn` | pill button: `ink`, `action`, `private`, `neutral`, `ghost`, `danger`; `busy`, `armDelay` |
| `Card`, `InfoRow`, `Notice`, `Tag` | surfaces, label/value rows, inline notes, status tags |
| `Field`, `TextBox` | single- and multi-line inputs; `TextBox.maxBytes` counts UTF-8 bytes |
| `Spinner`, `Skeleton` | pending and loading states |
| `Identicon`, `LogosMark`, `Glyph` | account avatar, the official Logos mark, a few line glyphs |

Onest is SIL OFL 1.1 (`fonts/OFL.txt`); glyph paths are Lucide (ISC).
