# Releasing the Basecamp modules

Basecamp installs Logos Kit from the catalog repo
[`logos-kit/logos-kit-modules`](https://github.com/logos-kit/logos-kit-modules).
The catalog pins one commit of this repo as `submodules/logos-kit` and
publishes two modules from it:

| Module | Path |
|---|---|
| `logos_kit_wallet` (core) | `modules/logos_kit_wallet` |
| `logos_kit_wallet_ui` (ui_qml) | `modules/logos_kit_wallet_ui` |

`probe_dapp` is dev-only and never published.

## Cutting a release

1. **Bump both `metadata.json` versions to the same number.** The UI calls the
   core methods it was built with, so the pair always ships together. The
   catalog's gate refuses a version skew.
2. **Rehearse the build the way CI runs it**: from a git checkout, `cd` into
   each module and build the portable bundle.
   ```bash
   cd modules/logos_kit_wallet    && nix build .#lgx-portable --no-link --print-out-paths
   cd ../logos_kit_wallet_ui      && nix build .#lgx-portable --no-link --print-out-paths
   ```
   A plain copy of the tree won't do, because the UI flake's
   `path:../logos_kit_wallet` input needs a git checkout.
3. **Merge to `main` here.** The catalog only auto-releases commits that are on
   this repo's `main`.
4. **Move the catalog pointer.**
   ```bash
   cd logos-kit-modules
   git -C submodules/logos-kit fetch origin main
   git -C submodules/logos-kit checkout origin/main
   git add submodules/logos-kit && git commit -m "logos-kit <version>" && git push
   ```
   `release-on-merge.yml` then builds `darwin-arm64`, `linux-amd64` and
   `linux-arm64`, signs, publishes `logos_kit_wallet-v<version>` and then
   `logos_kit_wallet_ui-v<version>`, and rebuilds `index.json`.
5. **Check the install** in a clean Basecamp: Settings → Package Repositories →
   add `https://raw.githubusercontent.com/logos-kit/logos-kit-modules/refs/heads/main/logos-repo.json`,
   then install Logos Kit Wallet from the App Manager.

A failed or partial release heals on the next push to the catalog's `main`, or
by running **Release on merge** by hand. To replace a release at the same
version, run the per-module workflow with **Force build**.

## Signing key

Packages are signed inline in CI with an Ed25519 key made by
`lgx keygen --name logos-kit-release`.

- The secret key is the catalog's `LOGOS_SIGNING_KEY` Actions secret. The
  maintainer's copy is `~/.config/logos/keys/logos-kit-release.jwk`; keep an
  offline backup.
- The public DID is the only `trustedSigners` entry in the catalog's
  `logos-repo.json`.

To rotate: make a new key, add its DID to `trustedSigners` next to the old one,
swap the secret, release, then remove the old DID once installs have moved over.
