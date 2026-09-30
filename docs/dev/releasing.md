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
  maintainer's copy is `~/.config/logos/keys/logos-kit-release.jwk`. Backups
  (made 2026-09-27, each checked against the key's SHA-256):
  - `~/.config/logos/keys-backup/logos-kit-release-keys.tar.age`: the whole
    `keys/` directory, encrypted with [age](https://age-encryption.org) to the
    maintainer's SSH keys (`id_ed25519`, `id_ed25519_20260922`);
  - the same file on agari-box at `/root/backups/logos-kit/`;
  - macOS login Keychain, service `logos-kit-release.jwk`, account `logos-kit`
    (stored base64).

  To restore:

  ```sh
  age -d -i ~/.ssh/id_ed25519 logos-kit-release-keys.tar.age | tar -xf - -C ~/.config/logos
  # or, from the Keychain:
  security find-generic-password -a logos-kit -s logos-kit-release.jwk -w | base64 -d > ~/.config/logos/keys/logos-kit-release.jwk
  ```

  The encrypted copies are only as safe as the SSH private key; keep that key
  backed up too.
- The public DID is the only `trustedSigners` entry in the catalog's
  `logos-repo.json`.

To rotate: make a new key, add its DID to `trustedSigners` next to the old one,
swap the secret, release, then remove the old DID once installs have moved over.

## npm packages (`@logos-kit/protocol`, `codec`, `client`, `theme`)

Versions come from [changesets](https://github.com/changesets/changesets): add one with
`pnpm changeset` in the PR that changes a package. On `main`,
`.github/workflows/changesets.yml` opens a "chore: version packages" PR; merging
it publishes to npm through **trusted publishing** (OIDC, with provenance). No npm
token is stored in the repo or in GitHub.

One-time setup, done by an owner of the npm org `logos-kit` (needs 2FA; run in a
terminal so npm can ask for the code):

```bash
for p in protocol codec client theme; do
  npm trust github @logos-kit/$p --file changesets.yml --repo logos-kit/logos-kit
done
```

The GitHub org must also allow Actions to open PRs (Settings → Actions → General →
Workflow permissions → "Allow GitHub Actions to create and approve pull requests").

History:
- 0.1.0 (2026-09-30) was published by hand. npm placed `@logos-kit/codec@0.1.0`
  in its staged-release review; the review cleared the same day and
  `latest` moved from npm's `0.0.0-stage` placeholder to `0.1.0`.
