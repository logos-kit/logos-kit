# Cutover to the official LEZ testnet 0.3

Logos Kit runs on its own preview network (`lez:preview`, LEZ `v0.3.0-rc1`) until the official testnet at `https://testnet.lez.logos.co` runs 0.3. This runbook is the switch.

**Why it matters:** LP-0021 only counts testimonials and flows on the official network. The two-month adoption clock can't start before this runbook is done.

Work through it top to bottom. Tick each box in the PR description, and paste the output where a step asks for evidence.

## 0. Detect

- [ ] Check the official testnet:
  ```sh
  cargo xtask fingerprint https://testnet.lez.logos.co
  ```
  Continue only when all of these hold:
  - `"version": "0.3"`;
  - `"headDecodesAsPinned": true`;
  - `"halted": false`;
  - `getFeeState` answers.

  If it reports 0.3 but the head doesn't decode with our pin, go to §1: upstream changed the format since our pin.
- [ ] Record the date, the tip block and the output in `PROGRESS.md`.

## 1. Pin

- [ ] Find the release tag the network runs, then compare it with our pin (`LEZ_REV` in `crates/xtask/src/main.rs`, currently `f7fda38`, which is `v0.3.0-rc1`):
  ```sh
  gh release list -R logos-blockchain/logos-execution-zone --limit 5
  gh api repos/logos-blockchain/logos-execution-zone/compare/f7fda38a4428b9989f1db1dbf5d2411484848fd4...v0.3.0 --jq '.status, .ahead_by'
  ```
- [ ] **If the tag equals our pin:** skip to §2.
- [ ] **If it differs:**
  1. Set `LEZ_REV` to the tag's commit.
  2. Re-apply the patches with `rm -rf vendor/lez && scripts/lez-vendor.sh`. Fix any conflict in `vendor/lez`, commit it there, then run `cargo xtask lez-export`.
  3. Update `flake.nix`'s LEZ source and the circuits/rapidsnark pins together (`docs/dev/pins.md`, "Engine build").
  4. Record the re-pin and the reason in `docs/dev/pins.md`.

## 2. Validate the codec and engine against the new chain

- [ ] Run the checks:
  ```sh
  cargo xtask vectors      # regenerate protocol/vectors from the pinned LEZ
  git diff --stat protocol/vectors
  (cd packages/codec && pnpm test)
  cargo clippy --workspace --all-targets -- -D warnings && cargo test --workspace
  ```
  - Any vector diff means a wire change: fix `packages/codec` until its tests pass.
  - Rebuild the QML bundle (`pnpm build && just qml-vendor`) and run `just qml-gate`.
- [ ] Run a local rehearsal on the pinned source: `e2e/demo.sh --local`, which must say `DEMO OK`. Then run `e2e/demo.sh --local --real-proofs` once.

## 3. Fees

- [ ] Compare `getFeeState` on the official network with the preview:
  ```sh
  curl -s https://testnet.lez.logos.co -H 'content-type: application/json' -d '{"jsonrpc":"2.0","id":1,"method":"getFeeState","params":[]}'
  ```
  - If the base fee or its semantics changed, check `wallet::max_fee_for` and the approval sheet's fee cap.
  - Check whether 0.3 exposes gas used in receipts; if it does, show it in the activity row. Otherwise the UI says "unavailable".
- [ ] Confirm that private transactions pay fees now (upstream issue #859), and whether the shield path needs a fee payer.

## 4. The testimonial program

- [ ] If §1 changed the pin, rebuild in the pinned docker builder and check the image id:
  ```sh
  target/release/logos-kit testimonial build          # writes programs/testimonial/artifacts/{testimonial.bin,build.json}
  jq -r .imageId programs/testimonial/artifacts/build.json
  ```
  If the image changed, commit the new artifacts. The engine trusts the image in `build.json` through `testimonial::build()` / `is_image()`.
- [ ] Fund a deployer on the official network. Use the official faucet if 0.3 ships one (§5); otherwise ask the Logos team for testnet funds.
- [ ] Deploy **immutable**, which is the default:
  ```sh
  LOGOS_KIT_ZONE=lez-testnet target/release/logos-kit testimonial deploy --payer <deployer> --yes --json | tee /tmp/testnet-deploy.json
  LOGOS_KIT_ZONE=lez-testnet target/release/logos-kit program "$(jq -r .account /tmp/testnet-deploy.json)" --json   # must say status verified_local, immutable true
  ```
- [ ] Add the registry entry to `registry/programs.json`, next to the `lez:preview` one:
  - `name: "testimonial"`, `chain: "lez:testnet"`;
  - `account`, `imageId` and `source` from `/tmp/testnet-deploy.json`.
- [ ] Add the SDK entry `'lez:testnet': '<account>'` to `TESTIMONIAL_PROGRAMS` in `packages/codec/src/programs.ts`.
- [ ] Rebuild and re-vendor: `pnpm build && just qml-vendor`.

## 5. The faucet backend for `lez:testnet`

- [ ] Choose the backend.
  - **The official faucet, if the 0.3 deployment ships one:** add a backend for it in `crates/wallet-engine/src/faucet.rs`. Follow the `FaucetBackend` trait, and classify outcomes the same way: `funded` only when the balance moved by exactly the drop.
  - **Otherwise the drip:** run `logos-kit-drip` for the testnet with a funded testnet key, as a second service in `deploy/` alongside the preview's. Add a `TESTNET_FAUCET` next to `PREVIEW_FAUCET` in `crates/wallet-engine/src/session.rs`, and select it in `service.rs` (search for `PREVIEW_FAUCET`).
- [ ] Update the docs faucet page and the Networks page to name the backend and its limits.

## 6. The default network

The testnet becomes the default. Preview stays listed until it's retired.

- [ ] Change the default in each place:
  - **Engine:** in `crates/wallet-engine/src/session.rs`, `Zone::builtin()` puts `Self::testnet()` first. In `crates/wallet-engine/src/service.rs`, `current_zone()` falls back to `Zone::testnet`.
  - **CLI:** in `crates/logos-kit-cli/src/main.rs`, change `default_value = "lez-preview"` to `"lez-testnet"`, and update the help text.
  - **SDK:**
    - `packages/qml-bundle/src/facade.ts` falls back to `CHAINS.lezTestnet`;
    - `sdk/qml/LogosKit/LogosKit.qml` sets `property string chain: "lez:testnet"`;
    - then `pnpm build && just qml-vendor`.
  - **Wallet UI labels:** `Home.qml` and `Onboarding.qml` already name all three networks; check them.
- [ ] Existing preview wallets keep their saved zone. Check that switching networks in the wallet (Settings → Network) still works.

## 7. Release

- [ ] Bump the versions:
  - `modules/logos_kit_wallet/metadata.json`, `modules/logos_kit_wallet/logos_kit_wallet.lidl` (`version`) and `modules/logos_kit_wallet_ui/metadata.json`, all to the same version;
  - the apps (`logos_kit_testimonial`, `logos_kit_faucet`) if their QML changed.

  `just qml-vendor` also re-copies the template's `.lidl`.
- [ ] Rehearse the builds: `for m in logos_kit_wallet logos_kit_wallet_ui logos_kit_testimonial logos_kit_faucet; do (cd modules/$m && nix build .#lgx-portable --no-link); done`.
- [ ] Merge to `main`, with green CI (Rust, TypeScript and docs, E2E). Then move the catalog pointer and push, as in `docs/dev/releasing.md`.
- [ ] Clean installs: `e2e/catalog-install.sh` (macOS), `e2e/catalog-install.sh --docker` (Linux arm64 and x86_64), and `e2e/catalog-install-gui.sh`. The GUI screenshot must show the testnet as the network.

## 8. Docs

- [ ] Update these pages:
  - `apps/docs/content/docs/networks.mdx` (or its successor): the testnet is the default, preview is retired or kept, the faucet, and the testimonial program id;
  - the quickstart, the testimonial guide and the README status table;
  - `PROGRESS.md`.
- [ ] Deploy the docs (Vercel project `logos-kit-docs`).

## 9. Prove the four asset routes on the official network, with real proofs

- [ ] Run the flows against the official network with a fresh wallet:
  ```sh
  LK_ZONE=lez-testnet e2e/preview-flows.sh
  ```
  Every step must end `ok … (block N)`:
  - faucet;
  - public send;
  - shield;
  - private to public;
  - public token send;
  - private token send;
  - testimonial.

  Save the log and the block numbers in `PROGRESS.md`.
- [ ] Run the two mini-apps in a real Basecamp against the testnet, and screenshot every state (`e2e/basecamp-apps.sh`, pointed at the testnet).

## 10. Start the evidence

- [ ] Take the first snapshot:
  ```sh
  LOGOS_KIT_ZONE=lez-testnet target/release/logos-kit testimonial evidence --snapshot adoption/snapshots --json
  ```
- [ ] Schedule it daily: a workflow that runs the CLI and commits `adoption/snapshots/<submission>-<date>.json`. The monthly counts go into `adoption/tracker.md`.
- [ ] Announce the switch, using the drafts in `adoption/drafts/`. **Only with the maintainer's go-ahead.**

## Rollback

Keep `lez:preview` as the default, or restore it by reverting the §6 commit and releasing a patch version, if any of these hold:
- the official fingerprint stops decoding with our pin (§0);
- a §9 route fails on the official network and can't be fixed within the day;
- the official network halts, or is reset within the first week.

In every case:
- the testimonial registry entries stay;
- the program is immutable, so it doesn't need rolling back;
- a failed catalog release is replaced by re-running the per-module workflow with **Force build** at the previous version (`docs/dev/releasing.md`).
