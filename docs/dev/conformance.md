# Conformance kit: test your Basecamp dApp against a fake wallet

The kit runs your dApp's real QML against **a fake Logos Kit wallet** that answers every call
and every wallet prompt from a fixed **scenario**: the user declines, the send times out, the
transaction lands with an unknown outcome, the faucet is rate-limited, the user switches
network, and so on. It needs no sequencer, no keys and no test funds, and a run gives the
same answers every time.

It is made of:

| Part | Where | What it is |
|---|---|---|
| Fake engine | `modules/logos_kit_wallet_fake/engine` | Same C ABI as the real engine (`libwallet_engine`), scenarios in `src/lib.rs` (`SCENARIOS`) |
| Fake core module | `modules/logos_kit_wallet_fake/core` | The real `logos_kit_wallet` shim, LIDL and module name, linked to the fake engine. A drop-in for test profiles only |
| Fake provider | `modules/logos_kit_wallet_fake/ui` (`logos_kit_wallet_fake`) | `ui_qml` that provides the five wallet intents and answers them without a click; shows the scenario and the call log |
| Runner | `modules/logos_kit_wallet_fake/runner/conformance.py` | Headless host for your view: plays Basecamp's `logos` bridge, runs your journey once per scenario, checks what the dApp did |
| Capability matrix | `docs/protocol/capability-matrix.md` | What LWS-0 defines and what the real wallet and the fake support (`just capability-matrix`) |

## Quick start

```sh
just qt-setup                                   # once: Qt 6.9.2 (Basecamp's) for Python
just conformance path/to/your-dapp              # every scenario, headless (~5 min)
just conformance path/to/your-dapp --scenario reject --show   # one scenario, window visible
just conformance-basecamp path/to/your-dapp     # the same fake inside a real Basecamp
```

`path/to/your-dapp` is your `ui_qml` module directory (the one with `metadata.json`). Results,
one screenshot per scenario and the full call log land in `target/conformance/<name>/`
(`report.json`, `console.log`, `<scenario>.png`). The command exits non-zero if any scenario
fails.

## Your journey

The runner can't know your buttons, so you describe the user's side once, in
`conformance.py` next to your `metadata.json`:

```python
def journey(j):
    # Runs once per scenario, whatever the wallet answers: check the screen, don't assume.
    if not j.click("connect"):          # objectName of your connect button
        return
    j.settle()                          # wait until the app and the wallet are quiet
    if j.find("funds"):
        j.click("funds"); j.settle()
    j.type("to", j.other)               # a valid account nobody owns
    j.type("amount", "42")
    if j.click("send", timeout=5):
        j.settle(max_s=70 if j.scenario == "timeout" else 30)

def check(j, scenario):                 # optional: your own expectations
    if scenario == "unknown_outcome":
        j.expect("success" not in j.text().lower(), "shows success for an unconfirmed transaction")
```

`j` offers `click(name)`, `type(name, text)`, `settle()`, `wait(cond, s)`, `find(name)`,
`prop(name, key)`, `text()` (everything visible), `expect(cond, message)`, and `account`,
`other`, `scenario`. Give the controls you click an `objectName`. Without a journey the runner
only loads the view and checks what it does on its own. The template's journey is
`modules/logos_kit_wallet_fake/runner/journeys/my_lez_dapp.py`.

## Scenarios

The fake starts every scenario fresh, with the wallet on `lez:testnet`. The account it shares
is always the same valid id.

| Scenario | What the fake does |
|---|---|
| `happy` | Connect shares one public account (and a private handle if asked). Balance 1000000000. A send answers a handle; status reads go submitted → included/success. The faucet funds 1000000000. |
| `reject` | The user declines every wallet prompt: each intent answers `cancelled` (LWS-0 4001). |
| `timeout` | Like happy, but the send intent answers only after 50 s: the SDK times out at 45 s (6108) and the handle arrives late (`onLateResult`). |
| `stale` | The send is approved, then the chain moved: status goes signing → dropped with error 6106. Nothing was sent. |
| `unknown_outcome` | Included, outcome `unknown`, outcomeSource `none`. |
| `failed_onchain` | Included, outcome `failure` (own-account-invariant). |
| `rate_limited` | Balance 0. The faucet answers `rate_limited`, retryAfterSeconds 60. |
| `faucet_unknown` | Balance 0. The faucet answers `outcome_unknown`; the funds do arrive. |
| `no_funds` | Balance 0. A send is refused (`failed`, as in every scenario while the account is empty); the faucet funds it. |
| `network_switch` | After the first connect, the next `lez_chainId` answers `lez:local`; the old session is gone and calls naming `lez:testnet` get 4902. |
| `unavailable` | The wallet isn't running: every method answers 6109, every intent `unavailable`. |

Status answers advance one step per `lez_getTransactionStatus` read, so a watcher sees every
state. Chain data isn't simulated: `lez_readAccount` returns an empty account.

## What is checked

In every scenario:

| Check | Fails when |
|---|---|
| `no-js-errors` | The console shows a JavaScript error (TypeError, ReferenceError, …) |
| `lws0-methods-only` | The dApp calls something that isn't an LWS-0 method (e.g. `ui_*`), another module, or the blocking `callModule` |
| `params-valid` | A call's params don't match `protocol/schema/methods.json` |
| `intents-declared` | A prompt isn't declared in `metadata.json` `uses`, or isn't an LWS-0 intent |
| `intent-params-valid` | A prompt's params don't match its method's schema |
| `prompts-follow-user-actions` | A wallet prompt opens without a user action before it: on load, or as an automatic retry |
| `user-steps-via-intents` | A user-facing method (send, sign, faucet…) is called directly instead of through its intent |
| `known-handles` | The dApp reads the status of a handle the wallet never gave it |
| `polling-stops` | Status polling goes on after a final lifecycle, or runs over 120 reads |
| `no-call-storm` | More than 50 calls in any 5 s |
| `unique-proposal-ids` | A proposal `id` is reused |
| `journey-expectations` | Your `check()` (or your journey) recorded a problem |

Per scenario: `happy-path-completes` (connects; every transaction followed to a final state),
`late-result-followed` (timeout: the late handle is still read), `follows-network-switch`
(re-reads the session and stops naming the old chain), `unknown-funds-rechecked`
(faucet_unknown: re-reads the balance), `unknown-outcome-verified` (unknown_outcome: a
follow-up read instead of taking "included" as success).

## In a real Basecamp

`just conformance-basecamp <dapp> [scenario] [connect objectName]` builds the fake core, the
fake provider and your dApp (`nix build .#lgx-portable`), installs them with `lgpm` into an
isolated profile (`/tmp/lk-conformance-<name>`), starts Basecamp with the scenario, opens your
app, presses its connect button, picks the fake in the shell's chooser and reads the fake's
call log. It checks that your view loads in the sandbox, that its calls reach the wallet with
its attested module name, and that a connect goes through the shell and comes back. It needs
Basecamp's inspector build and `lgpm` in `~/.local/share/logos-tools`, and refuses to start while
another Basecamp is open. Switch scenarios in the fake's own tab.

The fake core installs **as `logos_kit_wallet`**, so a dApp reaches it exactly as it reaches the
real wallet. Only install it into a test profile, never next to a real wallet.

## Limits

- The headless runner is not Basecamp: no sandbox, no chooser, no process hop, and intents
  come back after 150 ms. The Basecamp mode covers loading, identity and one connect, not
  each scenario's flow.
- The fake checks what the wallet checks at its edge (chain, grants, ids, instruction count)
  but decodes no instructions, proves nothing and keeps no chain state.
- A scenario's pass means the dApp did nothing wrong that the checks can see. Whether the screen
  tells the user the right thing is for your `check()` and the screenshots.
- Linux: the runner works where PySide6 6.9.2 does; the Basecamp mode script is macOS-only
  (`lgpm-aarch64-macos`), like `e2e/basecamp.sh`.
