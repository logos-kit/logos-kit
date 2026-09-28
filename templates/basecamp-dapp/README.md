# My LEZ dApp

A Basecamp app on the Logos Execution Zone (LEZ), built with the
[Logos Kit](https://github.com/logos-kit/logos-kit) SDK. It connects to the
user's wallet, reads a balance, gets test funds in the flow, proposes a
transfer the user approves in the wallet, and follows it to a receipt.

```sh
nix flake init -t github:logos-kit/logos-kit#dapp   # this folder, in an empty directory
nix build .#lgx-portable                            # → result-portable/*.lgx
```

Install the `.lgx` in Basecamp (Package Manager → Install from file, or
`lgpm install --file result-portable/*.lgx`). Users also need the Logos Kit
wallet; it installs from the Logos Kit catalog.

## Make it yours

1. In `metadata.json`, set `name` (lowercase, `_`), `display_name`,
   `description` and `category`. List every intent you use under `uses`.
2. Replace `src/icons/icon.png` (256×256).
3. Edit `qml/Main.qml`. The app follows the wallet's network, so switching
   the wallet to a local sequencer (Settings → Network) switches the app too.

## The SDK in one screen

`LogosKit { id: kit }` gives you `kit.api`. User-facing steps open the wallet
through Basecamp intents; reads go straight to the wallet module. Every call
returns a promise; errors are `{ code, message }`.

| Call | What happens |
|---|---|
| `connect({ accountKinds: ["public"] })` | The wallet asks which accounts to share → `Session` |
| `getSession()` | The current session, or `null` (no prompt) |
| `getWalletBalance(account)` | Balance of a shared account |
| `readAccount(account, program)` | A public account's data for one program |
| `transfer(from, to, amount)` | Propose a transfer; resolves when approved → `{ handle }` |
| `sendCall(account, call)` | Propose any program call (build it with `kit.sdk`) |
| `watchTransaction(handle, onUpdate)` | Status until final: `submitted` → `included` |
| `requestFunds(account)` | Test funds: `funded`, `rate_limited`, `outcome_unknown`, `rejected` |
| `signMessage(account, base64)` | A signature over your message |
| `openExplorer({ txHash })` | Opens the explorer in the user's browser |

`kit.sdk.isUserRejection(e)` tells "the user said no" apart from failures;
show nothing for it.

## Basecamp's sandbox

- No network from QML: read chain data through `kit.api`.
- No remote or `data:` images: bundle what you show.
- `Qt.openUrlExternally` is blocked: use `kit.api.openExplorer`.
- Render other people's text as plain text (`textFormat: Text.PlainText`;
  `LogosKitUi`'s `Txt` does this).

## Updating the SDK

`qml/LogosKit` and `qml/LogosKitUi` are copies of `sdk/qml/` from the Logos
Kit repository, and `logos_kit_wallet.lidl` is the wallet module's contract.
Replace them together when you move to a newer wallet.

Licence: MIT or Apache-2.0, like Logos Kit.
