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
| `basecamp-01-install.png` | Basecamp's **Applications** list with the Logos Kit catalog added and **Logos Kit Wallet** showing **Install** (window) | `apps/docs/public/shots/catalog-install.webp` |
| `basecamp-02-create.png` | The wallet's welcome screen: **Create wallet**, **Restore from recovery phrase**, the network picker | `apps/docs/public/shots/wallet-welcome.webp` (pre-Ledger) |
| `basecamp-03-phrase.png` | The 24-word phrase grid after **Reveal**, with **I've saved it** (throwaway wallet) | `apps/docs/public/shots/wallet-phrase.webp` (pre-Ledger) |
| `basecamp-04-test-lgo.png` | Home after **Test LGO**: "Public balance", 1 LGO, the Send / Receive / Test LGO tiles, and the faucet row in Activity | `apps/docs/public/shots/ledger/home-light.webp` (no activity row) |
| `basecamp-05-accounts.png` | The accounts sheet with two public and one private account, one being renamed, and the **Public account** / **Private account** buttons | `apps/docs/public/shots/wallet-accounts.webp` (pre-Ledger) |
| `basecamp-06-receive.png` | **Receive** on a private account: "Receive privately", the QR code, "Code ends …" and **Copy receive code** | `apps/docs/public/shots/ledger/receive-dark.webp` (dark) |
| `basecamp-07-send.png` | The review of a public send: amount, the full destination, the fee and **Send** | `apps/docs/public/shots/ledger/review-light.webp` |
| `basecamp-08-private.png` | A shield proving: the progress steps, the "On this device" proof row and **Keep running in background** | `apps/docs/public/shots/ledger/proving-dark.webp` (dark) |
| `basecamp-09-connect-app.png` | Basecamp with Logos Kit Testimonials and the wallet's approval sheet for a post: the app's name and icon, the program and its verification, the fee (window) | `apps/docs/public/shots/testimonial-basecamp.webp` (after posting) |

Present already: `logo-light.svg` (the official Logos mark, black, on the
Ledger light surface `#f5f5f7`) and `logo-dark.svg` (a copy of the shipped app
icon, `assets/app-icon/logos-kit-wallet.svg`).

Also planned, not referenced by the README: a 1280×640 social preview image
for the repository settings.
