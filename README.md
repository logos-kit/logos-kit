# Logos Kit

A wallet and connect kit for the **Logos Execution Zone (LEZ)**. It has public and private accounts, the token program, and a Wallet Provider SDK. It runs on three surfaces:

- **Basecamp desktop (QML)**: the Logos Kit wallet app, plus a QML SDK for Basecamp apps.
- **Web (React)**: a wagmi-style hooks SDK, a RainbowKit-style connect modal, and an embedded passkey wallet.
- **Mobile (React Native / Expo)**: the same hooks, with a native UI.

> **Status: early development.** Built for Logos λPrize LP-0021 (*LEZ Wallet and Provider SDK*). Progress is tracked in [`PROGRESS.md`](PROGRESS.md) and the plan is in [`docs/dev/PLAN.md`](docs/dev/PLAN.md).

## Repository layout

| Path | What |
|---|---|
| `protocol/` | LWS-0, the wallet protocol shared by every surface: JSON Schema, fixtures, test vectors |
| `crates/` | Rust: `wallet-engine` (keys, accounts, sync, approvals, proving), the `logos-kit` CLI, `xtask` |
| `modules/` | Basecamp modules: the core wallet module, the wallet UI, the testimonial and faucet mini-apps, a fake wallet for integrators |
| `programs/` | On-chain programs (RISC Zero guests), starting with the testimonial program |
| `sdk/qml/` | The `LogosKit` QML SDK for Basecamp apps |
| `packages/` | npm packages under `@logos-kit/*` |
| `apps/` | Docs site, embedded-wallet origin, playground, Expo example |
| `e2e/` | End-to-end tests against a standalone LEZ sequencer |

## Development

Setup, build and usage instructions arrive with each stage. See `PROGRESS.md`.

## License

Dual-licensed under [MIT](LICENSE-MIT) and [Apache-2.0](LICENSE-APACHE), at your option.
