# Basecamp modules

Each folder is one Logos Basecamp module, built with
[`logos-module-builder`](https://github.com/logos-co/logos-module-builder)
(pinned in each `flake.nix`; see [`docs/dev/pins.md`](../docs/dev/pins.md)).

| Module | Type | What it is | Published |
|---|---|---|---|
| [`logos_kit_wallet`](logos_kit_wallet) | `core` | The wallet core: the Rust engine (`crates/wallet-engine`) behind a LIDL contract (`logos_kit_wallet.lidl`). Keys, accounts, approvals, proving | Catalog |
| [`logos_kit_wallet_ui`](logos_kit_wallet_ui) | `ui_qml` | The wallet app, and the provider of the `lez.*` wallet intents | Catalog |
| [`logos_kit_testimonial`](logos_kit_testimonial) | `ui_qml` | Logos Kit Testimonials, built on the SDK | Catalog |
| [`logos_kit_faucet`](logos_kit_faucet) | `ui_qml` | Logos Kit Faucet, built on the SDK | Catalog |
| [`logos_kit_wallet_fake`](logos_kit_wallet_fake) | core + `ui_qml` | The conformance fake wallet, for testing apps ([README](logos_kit_wallet_fake/README.md)) | No |
| [`probe_dapp`](probe_dapp) | `ui_qml` | Dev-only app that drives the wallet's intents | No |

Each version is in the module's `metadata.json`. The wallet core and UI always
ship with the same version, because the UI calls the core methods it was built
with.

## Build from source

Each module builds to a portable `.lgx` package that Basecamp installs
directly. Build from a git checkout: the app flakes refer to the core module
as `path:../logos_kit_wallet`, which needs one.

```sh
cd modules/logos_kit_wallet        && nix build .#lgx-portable   # core (Rust engine inside)
cd ../logos_kit_wallet_ui          && nix build .#lgx-portable   # wallet UI
cd ../logos_kit_testimonial        && nix build .#lgx-portable
cd ../logos_kit_faucet             && nix build .#lgx-portable
```

`just lgx <module>` does the same from the repository root (output in
`modules/<module>/result-portable`), and `just lgx-dev <module>` builds the
development variant (`nix build .#lgx`). The first build of the core takes a
while on a cold Nix cache.

Install each `result/*.lgx` with Basecamp's **Package Manager → Install from
file**, or `lgpm install --file <file>.lgx`.

## Test in Basecamp

- `just bc-flow`: builds the wallet and the probe app, then drives connect →
  send → approve → status in a real Basecamp (`e2e/basecamp.sh`).
- `e2e/basecamp-apps.sh`: the Testimonials and Faucet apps in a real Basecamp.
- `just catalog-install` and `just catalog-install-gui`: install from the
  published catalog, headless and in the GUI.
- `just basecamp-reset`: clears local Logos Kit installs from a Basecamp
  profile.

## Release

Releases go through the catalog repository,
[`logos-kit/logos-kit-modules`](https://github.com/logos-kit/logos-kit-modules),
which builds `darwin-arm64`, `linux-amd64` and `linux-arm64`, signs each
package with the Logos Kit release key and updates the index. The steps are in
[`docs/dev/releasing.md`](../docs/dev/releasing.md).
