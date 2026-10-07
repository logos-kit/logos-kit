# README assets still to make

The root `README.md` already points at these files. Take every screenshot from
the real wallet in the current "Ledger" design, on the official LEZ testnet
(the network pill reads **Testnet**), with a fresh wallet. No `sslip.io` hosts,
private data or real recovery phrases may be visible; use a throwaway wallet
for the phrase shot.

Format: PNG, about 2× scale. Basecamp window shots are trimmed to the window;
wallet-sheet shots are trimmed to the panel (the README shows them 360 px wide,
window shots 640 px). Make one file per name, in light mode unless noted;
the README picks no dark variants.

| File | Shows | Interim reference |
|---|---|---|
| `hero.gif` | The whole connect → pick → approve → landed loop, about 10–15 s, 1440 px wide or less, under 5 MB: an app's **Connect wallet**, the wallet's "Share which accounts?" sheet with one account picked and **Connect**, the app's **Post testimonial**, the wallet's approval sheet (app name, program, verification, fee) and **Approve**, then the app's **Posted on LEZ** | `apps/docs/public/shots/testimonial-basecamp.webp`, `ledger/connect-dark.webp`, `ledger/approval-dark.webp` |
| `cli.gif` | A terminal recording (for example a VHS tape): `logos-kit init`, `account new`, `faucet`, `send … --amount 0.25` with its review and `Approve? [y/N]`, then a `shield` showing "proving locally" (cut the wait) and the final "tx … in block … (outcome: Success)" | none |
| `basecamp-09-connect-app.png` | Basecamp with Logos Kit Testimonials and the wallet's approval sheet for a post: the app's name and icon, the program and its verification, the fee (window) | `apps/docs/public/shots/testimonial-basecamp.webp` (after posting) |

Made from the real wallet (`modules/logos_kit_wallet_ui/dev/qa_readme.py`, light, 2×, on the testnet):
`basecamp-02-create.png` … `basecamp-08-private.png`. `basecamp-01-install.png` is the real Basecamp
install run (`e2e/catalog-install-gui.sh`, `docs/reviews/a/catalog/`).

Present already: `logo-light.svg` (the official Logos mark, black, on the
Ledger light surface `#f5f5f7`) and `logo-dark.svg` (a copy of the shipped app
icon, `assets/app-icon/logos-kit-wallet.svg`).

Also planned, not referenced by the README: a 1280×640 social preview image
for the repository settings.
