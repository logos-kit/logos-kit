# Contributing

Thanks for helping build Logos Kit.

- Read [`AGENTS.md`](AGENTS.md) for the project rules. They apply to everyone.
- One topic per pull request; keep commits small.
- JS/TS: `pnpm check` (Biome) and `pnpm build` must pass. Add a changeset
  (`pnpm changeset`) for any user-facing package change.
- Rust: `cargo fmt` and `cargo clippy --workspace --all-targets -- -D warnings`
  (`just check-rust` runs both).
- Basecamp modules: build with `nix build .#lgx` in the module folder; see
  [`modules/README.md`](modules/README.md).
- Contributions are dual-licensed under MIT and Apache-2.0, as described in the
  [README](README.md#license).

## Repository layout

| Path | What |
|---|---|
| `crates/wallet-engine` | The Rust engine: keys, vault, accounts, sync, policy, approvals, proving (no Qt) |
| `crates/logos-kit-cli` | The `logos-kit` CLI ([README](crates/logos-kit-cli/README.md)) |
| `crates/logos-kit-drip` | The self-hostable testnet faucet |
| `crates/lwsp-types` | LWS-0 (the wallet protocol) types, generated from its JSON Schema |
| `crates/xtask` | `cargo xtask`: LEZ vendoring, network fingerprint, test vectors, types |
| `modules/` | Basecamp modules: the wallet core and UI, the Testimonials and Faucet apps, the conformance fake, a dev-only probe ([README](modules/README.md)) |
| `sdk/qml/` | `LogosKit`, the QML SDK ([README](sdk/qml/LogosKit/README.md)), and `LogosKitUi`, the wallet's look as components |
| `packages/`, `protocol/` | `@logos-kit/client`, `codec`, `theme` and `protocol` on npm; `packages/qml-bundle` builds the QML SDK from them |
| `programs/testimonial/` | The testimonial program, with a reproducible build ([README](programs/testimonial/README.md)) |
| `registry/` | Programs the wallet recognises (`programs.json`) and the rebuilt LEZ builtins (`builtins.json`) |
| `templates/basecamp-dapp/` | The app template (`nix flake init -t github:logos-kit/logos-kit#dapp`) |
| `apps/docs/` | The docs site ([README](apps/docs/README.md)); `apps/design-lab` is the web design reference |
| `e2e/`, `tests/` | End-to-end scripts: a local sequencer, real Basecamp, the hosted networks |
| `deploy/` | Logos Kit's hosted services: the testnet faucet and CORS relay, the preview network ([README](deploy/README.md)) |
| `vendor/` | `lez-patches/`, our patch series on LEZ; `scripts/lez-vendor.sh` materialises `vendor/lez` |
| `docs/dev/` | Plans, the pins (`pins.md`), releasing, the criteria audit, the testnet cutover |

## Develop

```sh
scripts/lez-vendor.sh                                # once: the pinned LEZ + our patches into vendor/lez
pnpm install && pnpm build && pnpm check:types       # TypeScript
cargo test -p wallet-engine --lib                    # engine unit tests
just e2e-cli                                         # CLI flows on a local sequencer (dev proofs)
just e2e-tokens                                      # token routes on a local sequencer
e2e/preview-flows.sh --tokens-only                   # the preview network, one real proof
LK_ZONE=lez-testnet e2e/preview-flows.sh             # every route on the official testnet, real proofs
(cd apps/docs && pnpm dev)                           # the docs site on :3000
just --list                                          # everything else
```

The local sequencer (`e2e/standalone.sh`) needs `r0vm` 3.0.5:
`curl -L https://risczero.com/install | bash && rzup install r0vm 3.0.5`.
`cargo xtask lez-vendor` does the same as `scripts/lez-vendor.sh` once
`vendor/lez` exists; on a clean clone use the script, since `xtask` itself
depends on the LEZ crates.

Every pinned revision is in [`docs/dev/pins.md`](docs/dev/pins.md). Don't bump a
pin without recording why. Releases to the Basecamp catalog and to npm:
[`docs/dev/releasing.md`](docs/dev/releasing.md).
