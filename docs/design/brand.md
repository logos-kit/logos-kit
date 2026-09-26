# Brand

## Logos Kit
- **Name:** Logos Kit. **npm:** `@logos-kit/*`. **Modules:** `logos_kit_*`. **CLI:** `logos-kit`.
- **Testimonial wording:** "I use Logos Kit wallet …"
- **Colours:** come from `@logos-kit/theme`. The accent and status tokens follow RainbowKit and wagmi conventions, not the Logos site palette (maintainer rule).
  - In Basecamp, native surfaces (background, surfaces, borders, typography) still come from `Logos.Theme`, so the app feels at home.
- **App icon (256×256):** a placeholder for now, from the module-builder template. It will be designed in S7 using the official Logos mark, unmodified, on our surface colour.

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
