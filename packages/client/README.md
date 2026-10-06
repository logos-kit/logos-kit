# @logos-kit/client

Typed client for the **Logos Execution Zone** (LEZ): node reads, the LWS-0 wallet actions a dApp uses to ask the Logos Kit wallet for things, and lossless u128 JSON. The root entry is QML-safe (no `BigInt`, no `Intl`), so the same code runs in Node, browsers and Basecamp's Qt engine.

```sh
npm install @logos-kit/client @logos-kit/codec
# pnpm add @logos-kit/client @logos-kit/codec  ·  yarn add @logos-kit/client @logos-kit/codec  ·  bun add @logos-kit/client @logos-kit/codec
```

## Read the chain

```ts
import { createClient, http, nodeActions } from '@logos-kit/client'

const node = createClient({
  transport: http('https://testnet.lez.logos.co', { retryCount: 2 }),
  chain: 'lez:testnet',
}).extend(nodeActions)

const height = await node.getBlockNumber()
const fees = await node.getFeeState()
```

The official LEZ testnet sends no CORS headers, so this works from Node and other non-browser runtimes, not from a web page. In a web page, read through an endpoint that sends CORS headers, such as Logos Kit's relay for the testnet ([Networks](https://logos-kit-docs.vercel.app/docs/concepts/networks)).

## Ask the wallet (inside a Basecamp app)

```ts
import { basecampModule, createClient, walletActions } from '@logos-kit/client'
import { nativeTransfer } from '@logos-kit/codec'

const wallet = createClient({
  transport: basecampModule({ callModuleAsync: logos.callModuleAsync }),
  chain: 'lez:testnet',
}).extend(walletActions)

const session = await wallet.connect({ chains: ['lez:testnet'] })
const from = session.accounts[0].address

// 1000 lepta (1 LGO = 10^9 lepta). Resolves when the user approves, not when the transaction lands.
const { handle } = await wallet.sendCall(from, nativeTransfer(from, to, '1000'))
const status = await wallet.waitForTransactionStatus(handle)
const done = status.outcome === 'success' // "unknown" is not success: re-check, then say "unconfirmed"
```

Keys never leave the wallet: an app proposes, the user approves, the wallet signs and proves. Private accounts reach an app only as opaque per-app handles.

`@logos-kit/client/local` adds raw-key signing for scripts and tests (Node only; never ship keys in an app).

## Status

`0.x`. The encoding is checked against test vectors generated from LEZ `v0.3.0`, the version the official testnet runs. Browser and React Native connect kits are planned, not shipped.

## Links

- Docs: [TypeScript client](https://logos-kit-docs.vercel.app/docs/sdk/client), [Transactions](https://logos-kit-docs.vercel.app/docs/concepts/transactions)
- Source: [logos-kit/logos-kit](https://github.com/logos-kit/logos-kit/tree/main/packages/client)

## License

MIT OR Apache-2.0
