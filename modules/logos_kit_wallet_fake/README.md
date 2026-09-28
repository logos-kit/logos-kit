# logos_kit_wallet_fake: the conformance fake wallet

A deterministic stand-in for the Logos Kit wallet, for testing dApps. It holds no keys and
talks to no chain; every answer comes from a fixed scenario. Guide: `docs/dev/conformance.md`.

- `engine/`: the fake engine, a `libwallet_engine` with the real C ABI (`include/wallet_engine.h`).
  Scenarios live in `src/lib.rs` (`SCENARIOS`).
- `core/`: builds the real core module (`../logos_kit_wallet`: shim, LIDL, CMake) linked to the
  fake engine. It installs as `logos_kit_wallet`, so test profiles only.
- `ui/`: `logos_kit_wallet_fake`, the intent provider that answers every wallet prompt on its own.
- `runner/`: the headless conformance runner and the template's journey.

```sh
just conformance templates/basecamp-dapp
just conformance-basecamp templates/basecamp-dapp
```
