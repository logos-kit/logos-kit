# Changelog

What changed in Logos Kit: the wallet, its Basecamp apps, the CLI and the SDK.
The npm packages also keep their own changelogs, written by changesets
([`packages/client`](packages/client/CHANGELOG.md),
[`packages/codec`](packages/codec/CHANGELOG.md),
[`packages/theme`](packages/theme/CHANGELOG.md),
[`protocol`](protocol/CHANGELOG.md)). The docs site shows the same release
notes at [Changelog](https://logos-kit-docs.vercel.app/docs/changelog).

## Status (2026-10-06)

| Area | State |
|---|---|
| Default network | The official LEZ testnet (`https://testnet.lez.logos.co`, LEZ `v0.3.0`) in the wallet, the CLI and the SDK, with Logos Kit's testnet faucet and the testimonial program. The switch is recorded in [`docs/dev/cutover-0.3.md`](docs/dev/cutover-0.3.md). |
| Wallet in Basecamp | `logos_kit_wallet` (core) and `logos_kit_wallet_ui` from the [catalog](https://github.com/logos-kit/logos-kit-modules), signed by the Logos Kit release key, built for macOS arm64 and Linux x86-64 and arm64. This repo is at 0.3.0; the catalog's [index](https://github.com/logos-kit/logos-kit-modules/releases/download/index/index.json) lists what is published. |
| Public, private and token flows | Every route ran on the official testnet with real proofs, from a fresh wallet funded by the faucet (`LK_ZONE=lez-testnet e2e/preview-flows.sh`): public send (block 11969), shield (11978), private to public (11987), token create (11991), public token send (11994), token send into a private account (12002) and a testimonial (12004). |
| Testimonial and faucet apps | `logos_kit_testimonial` and `logos_kit_faucet`, from the same catalog. |
| QML SDK and app template | `sdk/qml/LogosKit` and `nix flake init -t github:logos-kit/logos-kit#dapp`. |
| TypeScript packages | On npm: `@logos-kit/client`, `@logos-kit/codec`, `@logos-kit/protocol` and `@logos-kit/theme` 0.1.1, for Node and tooling. |
| Conformance kit | A fake wallet with 11 scenarios; `just conformance <app dir>`. |
| Testimonial program | On the official testnet at `5YoH3xjhgeKt2mcJXW7c31bqDNCWWA4CRJxVdvzFvVef`: immutable, source verification `verified_local`. A copy on the preview network takes posts that don't count for LP-0021. |
| CI | `e2e.yml` runs the CLI flows against a LEZ 0.3 sequencer built from the pinned source (dev proofs) on `main` and every pull request; `valid-proof.yml` runs a real proof every night. |
| Planned | NFTs, private membership proofs and a Market in the next release. A web (React) connect kit, React Native and a passkey wallet later. |

Progress in detail: [`PROGRESS.md`](PROGRESS.md). Plan: [`docs/dev/PLAN-LP0001.md`](docs/dev/PLAN-LP0001.md).

## Releases

### Wallet 0.3.0, Testimonials 0.3.0, Faucet 0.3.0

- **New design ("Ledger").** One monochrome look for the wallet, both apps
  and the docs site, taken from real wallets: Fuse's balance and confirm sheet,
  Family's account header, send keypad and black dark mode, Phantom's action
  tiles and sending ring, Glow's connect sheet. Light and dark both; colour
  only for status. Private is shown by a lock and a label.
- **Approvals read like a sentence.** One line says what happens ("Send 1 LGO
  to Savings"), then the amount, the full destination and short rows.
  Native transfers show "Built into LEZ"; a program whose source doesn't
  match is labelled **Source mismatch**; a token transfer proposed by an app
  now shows the asset, amount and destination.
- **Verified by you counts.** A program you rebuilt with
  `logos-kit verify-program` shows as verified on approval sheets too.

### 2026-10-06 · Wallet 0.2.0, Testimonials 0.2.0, Faucet 0.2.0

- **The official LEZ testnet is the default.** The wallet, the CLI (`--zone`
  defaults to `lez-testnet`) and the SDK (`chain: "lez:testnet"`) use
  `https://testnet.lez.logos.co`, which runs LEZ `v0.3.0`. The engine is
  re-pinned to that release (`db66590`). The preview network stays listed for
  wallets that saved it. See
  [Networks](https://logos-kit-docs.vercel.app/docs/concepts/networks).
- **Testnet faucet:** Logos Kit's drip for the testnet, 1 LGO per request, each
  account once an hour. The wallet's **Get test LGO** and the SDK's
  `requestFunds` use it automatically.
- **Testimonial program on the testnet:**
  `5YoH3xjhgeKt2mcJXW7c31bqDNCWWA4CRJxVdvzFvVef`, immutable,
  `TESTIMONIAL_PROGRAMS["lez:testnet"]`. Posts there count for LP-0021. The
  wallet recognises only the `v0.3.0` testimonial image, so the preview
  network's program shows as unrecognised.
- **LGO units.** The native token is LOGOS (LGO), 1 LGO = 10^9 lepta. The
  wallet, the apps and the CLI show LGO with up to 9 decimals, nothing
  rounded. The SDK and the CLI's `--json` stay in lepta; `send --amount`
  also takes LGO (`2.5`, `2.5LGO`, `3 LGO`).
- **Slower inclusion handled:** the wallet waits up to about 6 minutes before
  it reports a send as not included.

### 2026-09-30 · Wallet 0.1.3, Testimonials 0.1.1, Faucet 0.1.1, npm 0.1.0

- **On npm:** [`@logos-kit/client`](https://www.npmjs.com/package/@logos-kit/client),
  [`@logos-kit/codec`](https://www.npmjs.com/package/@logos-kit/codec),
  [`@logos-kit/protocol`](https://www.npmjs.com/package/@logos-kit/protocol) and
  [`@logos-kit/theme`](https://www.npmjs.com/package/@logos-kit/theme) 0.1.0.
  Future releases publish from GitHub Actions through npm trusted publishing,
  with provenance.
- **Redesigned wallet and apps.** A new component kit ported from 21st.dev
  components: approval sheets lead with the asset, amount and full
  destination; proving shows a step timeline; toasts, sheets, skeleton
  loaders, an animated balance, a copy-to-check address chip; keyboard focus
  on every control and stronger contrast in both themes.
- **Token create confirms as `success`** from the holder's balance.
- **Testimonial evidence** counts each author's own transactions before their
  post (prior activity), read from the blocks.
- **Preview faucet:** restart-safe ledger (a request key is never paid twice),
  per-visitor limits, `Retry-After`.
- **Docs rewritten** with a new structure, guides per task, a CLI reference and
  current screenshots.

### 2026-09-28 · Wallet 0.1.2, Testimonials 0.1.0, Faucet 0.1.0

- **Preview network.** The wallet, CLI and SDK default to `lez:preview`, Logos
  Kit's public LEZ 0.3 network, with a built-in faucet. The official testnet
  still runs 0.2.
- **New apps in the catalog:** Logos Kit Testimonials and Logos Kit Faucet.
- **Approval sheets show the requesting app's icon and name,** with the module
  name Basecamp attests.
- **Testimonial posts re-check their stats page at signing,** so a page that
  filled during approval no longer costs a failed transaction.
- **Honest outcomes everywhere:** public token sends now confirm as `success`
  from the sender's token balance; the apps show Done only on `success`, with
  a "not confirmed yet" state for `unknown`.
- **SDK:** `lateResult` for approvals slower than 45 s; `lez_chainId` so apps
  follow the wallet's network; `lez_openExplorer` for sandboxed explorer links
  (connected apps only, rate-limited); private faucet claims report the public
  account that was paid (`fundedAccount`).
- **Conformance kit:** a scenario-driven fake wallet and `just conformance <dapp>`.
- **CLI:** the wallet folder flag is `--home` (`logos-kit call` works again).

### 2026-09-27 · Wallet 0.1.1

- The wallet's real app icon (0.1.0 shipped the template placeholder).

### 2026-09-27 · Wallet 0.1.0

- First catalog release: the Logos Kit core module and wallet app, signed,
  for macOS arm64 and Linux x86-64 and arm64.
- Public and private accounts, the native token and tokens, local proving, decoded
  approvals with source verification, grants, auto-lock, backups.
