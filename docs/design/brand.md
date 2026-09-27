# Brand

## Logos Kit
- **Name:** Logos Kit. **npm:** `@logos-kit/*`. **Modules:** `logos_kit_*`. **CLI:** `logos-kit`.
- **Testimonial wording:** "I use Logos Kit wallet …"
- **Colours:** come from `@logos-kit/theme`. The accent and status tokens follow RainbowKit and wagmi conventions, not the Logos site palette (maintainer rule).
  - In Basecamp, native surfaces (background, surfaces, borders, typography) still come from `Logos.Theme`, so the app feels at home.
- **App icon (256×256):** the official Logos mark (`Logos-Mark-White.svg`), unmodified, on Tray dark `surface` `#161618`, the mark's longer side 150 px. Source `assets/app-icon/logos-kit-wallet.svg`; rendered with `rsvg-convert -w 256 -h 256 … -o modules/logos_kit_wallet_ui/src/icons/icon.png`. 0.1.0 shipped the template placeholder by mistake; fixed in 0.1.1.

## Design direction: Tray (locked 2026-09-26, D14)

Chosen from three working prototypes (`apps/design-lab`, published for review). Tray follows Family's tray system: every step floats over the app in a card sized to its content, send starts at a keypad, numerals are big and friendly, and a proof keeps running in an island at the top of the view.

**Both sets ship.** Basecamp opens in Tray dark (the shell is dark-only). Web and React Native follow the system setting, with a switch.

| Token | Tray light | Tray dark | Role |
|---|---|---|---|
| `bg` | `#EBEBEF` | `#000000` | app background behind trays |
| `surface` | `#FFFFFF` | `#161618` | trays, cards, sheets |
| `surface2` | `#F3F3F6` | `#202023` | secondary buttons, rows, keypad |
| `line` | `rgba(14,14,18,.07)` | `rgba(255,255,255,.07)` | hairlines |
| `text` | `#0E0E12` | `#F4F4F6` | primary text; also the "ink" primary button |
| `text2` | `#6C6C78` | `#9A9AA5` | secondary text, units |
| `text3` | `#A2A2AD` | `#5F5F69` | hints |
| `private` | `#6B5FFF` | `#7A70FF` | **only** private state: badges, proof progress, private totals |
| `action` | `#1F7BFF` | `#3898FF` | public and neutral actions (connect, links) |
| `ok` / `warn` / `danger` | `#12A150` / `#D49A00` / `#E5484D` | `#4BD166` / `#FFD641` / `#FF6257` | status only |

- **Type:** Onest (400–800), bundled with every renderer; tabular figures for amounts; the unit (LEZ) is set smaller in `text2`.
- **Shape:** sheets 36 px, cards 26 px, rows 20 px, buttons are pills.
- **Motion:** sheets slide up with `cubic-bezier(.15,1.15,.6,1)` over 300 ms; height follows content over 200 ms `cubic-bezier(.25,.1,.25,1)`; steps swap with a 1.08 ↔ 0.94 scale; buttons press to 0.96. Everything turns off under reduced motion.
- **Source of truth:** `apps/design-lab/src/lab/tokens.ts` until `@logos-kit/theme` exists (S6), then the theme package.

## Official Logos marks (`assets/logos/logos/`)
Downloaded 2026-09-26 from the Logos Brand Guidelines, https://guide.logos.co/visual-language/logo.

| File | Use |
|---|---|
| `Logos-Mark-White.svg` / `.png` | The ecosystem mark on dark surfaces (connect screens, network badge) |
| `Logos-Mark-Black.svg` / `.png` | The ecosystem mark on light surfaces |
| `Logos-Horizontal-lockup-{White,Black}-Large.svg` | "Built on Logos" footers, docs |
| `Logos-Vertical-lockup-{White,Black}-Large.svg` | Docs landing, social cards |

**Rules** (from the guidelines):
- Don't edit, change, distort, recolour or reconfigure the Logos mark.
- Use the mark on our own surfaces, and a lockup in other contexts.
- Keep the clear space shown in the guide.

## Other logos
- Chain and wallet brand logos come from svgl via `21st logo <name>` (e.g. Ethereum, Solana).
- Token logos come from the token registry metadata, **bundled** into the app. Basecamp's sandbox blocks remote images. The fallback is a deterministic identicon.
- Never use generic glyph icons where a real logo exists.
