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

## Evaluate this submission

[![Rust](https://github.com/logos-kit/logos-kit/actions/workflows/rust.yml/badge.svg?branch=main)](https://github.com/logos-kit/logos-kit/actions/workflows/rust.yml)
[![E2E](https://github.com/logos-kit/logos-kit/actions/workflows/e2e.yml/badge.svg?branch=main)](https://github.com/logos-kit/logos-kit/actions/workflows/e2e.yml)
[![TypeScript and docs](https://github.com/logos-kit/logos-kit/actions/workflows/ts.yml/badge.svg?branch=main)](https://github.com/logos-kit/logos-kit/actions/workflows/ts.yml)

`e2e/demo.sh` runs every wallet flow non-interactively and prints one pass/fail line per step: faucet, public send, shield, private send, token create and transfers, testimonial deploy and post, evidence export, and refused approvals. It runs on macOS arm64 and Linux x86_64/aarch64, checks the prerequisites and prints install commands for anything missing.

```sh
git clone https://github.com/logos-kit/logos-kit && cd logos-kit
e2e/demo.sh --local                 # a LEZ 0.3 sequencer built from the pinned source, dev proofs; no hosted services
e2e/demo.sh --local --real-proofs   # the same with real RISC Zero proofs (minutes per private step)
e2e/demo.sh --preview               # the public Logos Kit preview network (LEZ 0.3-rc1, real proofs)
```

CI runs the same flows against a standalone sequencer on every push (`.github/workflows/e2e.yml`). The official LEZ testnet still runs 0.2; the switch to it is [`docs/dev/cutover-0.3.md`](docs/dev/cutover-0.3.md).

## License

Dual-licensed under [MIT](LICENSE-MIT) and [Apache-2.0](LICENSE-APACHE), at your option.
