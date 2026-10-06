# LogosKit (QML SDK)

What a Logos Basecamp app uses to ask the Logos Kit wallet for things: connect,
read, propose transactions and follow them to an outcome. Keys, grants and
approvals stay in the wallet; your app asks and the user decides.

Copy this folder into your `ui_qml` module's `qml/` folder (the app template,
`nix flake init -t github:logos-kit/logos-kit#dapp`, already has it), then:

```qml
import "LogosKit"

LogosKit {
    id: kit
    visible: root.visible            // status polling pauses while hidden
    onApiChanged: if (api) restore() // api is rebuilt when the wallet switches networks
}
```

List every intent your app uses under `uses` in `metadata.json`, as objects:

```json
"dependencies": ["logos_kit_wallet"],
"uses": [{ "intent": "lez.wallet.connect" }, { "intent": "lez.transaction.send" }]
```

## Properties

| Property | Default | Meaning |
|---|---|---|
| `chain` | `"lez:testnet"` | The network. Follows the wallet unless `followWallet` is off |
| `followWallet` | `true` | Check the wallet's network on start, when shown, and every 5 s while visible |
| `visible` | `true` | Bind to your view; hidden apps don't poll |
| `module` | `"logos_kit_wallet"` | The wallet core module |
| `api` | `null` until ready | The calls below. Read `kit.api` each time; don't keep a copy |
| `sdk` | | Helpers: `parseUnits`, `formatUnits`, `isUserRejection`, `isAccountId`, program builders (`nativeTransfer`, `tokenTransfer`, `testimonialPost`) |

Signal `lateResult(intent, ok, data)`: the wallet's answer to a request that
already timed out (45 s), such as a send the user approved late.

## Calls

Every call returns a promise. "Wallet sheet" calls open the wallet and wait
for the user; the others are reads.

| Call | Kind | Resolves to |
|---|---|---|
| `connect({ accountKinds, capabilities, signIn })` | wallet sheet | `{ sessionId, accounts[], chains, capabilities }` |
| `getSession()`, `getAccounts()`, `getChainId()` | read | the session, shared accounts, the wallet's network |
| `getWalletBalance(account, asset?)` | read | `{ amount, asset, synced, asOfBlock }` |
| `readAccount(account, program)` | read | `{ nonce, data }` |
| `transfer(from, to, amount, token?)` | wallet sheet | `{ handle }` once approved |
| `sendCall(account, call)`, `sendTransaction(proposal)` | wallet sheet | `{ handle }` |
| `postTestimonial({ program, author, text, username? })` | wallet sheet | `{ handle }` |
| `getTestimonials(program, { limit })`, `getTestimonial(program, author)` | read | the program's posts |
| `getTransactionStatus(handle)` | read | the status |
| `watchTransaction(handle, onUpdate, onError?)` | read (polls) | `{ stop() }`; stops at the first final lifecycle |
| `waitForTransactionStatus(handle)` | read (polls) | the first final status |
| `signMessage(account, base64)`, `signIn(request)` | wallet sheet | the signature |
| `requestFunds(account)` | wallet sheet | `{ status, amount?, retryAfterSeconds?, shieldHandle? }` |
| `openExplorer({ txHash } \| { account })` | read | opens the testnet explorer in the browser |
| `isBusy()` | | a wallet sheet is open for this app |

Amounts are strings in base units: lepta for the native token, 1 LGO = 10^9
lepta. `kit.sdk.parseUnits("2.5", 9)` gives `"2500000000"`;
`kit.sdk.formatUnits(amount, 9)` shows LGO. Never `Number()` them.

A proposal resolves when the user approves, not when it lands. Follow the
handle through `building → proving → signing → submitted → included` (or
`rejected`, `dropped`, `expired`), and read `outcome` on the final status: only
`success` means done; `unknown` means "included, not confirmed".

## Files

`logoskit.js` is generated from the TypeScript packages
(`packages/qml-bundle`, `just qml-sdk`) and `Tokens.js` from `@logos-kit/theme`.
Don't edit them by hand; `just qml-vendor` copies this folder into the apps and
the template.

Full reference: [QML SDK](https://logos-kit-docs.vercel.app/docs/sdk/qml),
[errors](https://logos-kit-docs.vercel.app/docs/reference/errors) and the
[testimonial app guide](https://logos-kit-docs.vercel.app/docs/guides/testimonial).
Source: [logos-kit/logos-kit](https://github.com/logos-kit/logos-kit/tree/main/sdk/qml/LogosKit).
License: MIT OR Apache-2.0.
