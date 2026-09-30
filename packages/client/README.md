# @logos-kit/client

Typed client for the **Logos Execution Zone** (LEZ): node reads, the LWS-0 wallet actions a dApp uses to ask the Logos Kit wallet for things, and lossless u128 JSON. The root entry is QML-safe (no `BigInt`, no `Intl`), so the same code runs in Node, browsers and Basecamp's Qt engine.

```sh
pnpm add @logos-kit/client @logos-kit/codec
```

## Read the chain

```ts
import { createClient, http, nodeActions } from '@logos-kit/client'

const node = createClient({
  transport: http('https://lez.84.46.247.92.sslip.io', { retryCount: 2 }),
  chain: 'lez:preview',
}).extend(nodeActions)

const height = await node.getBlockNumber()
const fees = await node.getFeeState()
```

The official LEZ sequencer sends no CORS headers, so from a browser only CORS-enabled endpoints work (the Logos Kit preview network is one). From Node there's no such limit.

## Ask the wallet (inside a Basecamp app)

```ts
import { basecampModule, createClient, walletActions } from '@logos-kit/client'
import { nativeTransfer } from '@logos-kit/codec'

const wallet = createClient({
  transport: basecampModule({ callModuleAsync: logos.callModuleAsync }),
  chain: 'lez:preview',
}).extend(walletActions)

const session = await wallet.connect({ chains: ['lez:preview'] })
const from = session.accounts[0].address

// Resolves when the user approves in the wallet, not when the transaction lands.
const { handle } = await wallet.sendCall(from, nativeTransfer(from, to, '1000'))
const status = await wallet.waitForTransactionStatus(handle)
const done = status.outcome === 'success' // "unknown" is not success: re-check, then say "unconfirmed"
```

Keys never leave the wallet: an app proposes, the user approves, the wallet signs and proves. Private accounts reach an app only as opaque per-app handles.

`@logos-kit/client/local` adds raw-key signing for scripts and tests (Node only; never ship keys in an app).

## Status

Preview (`0.x`). Built against LEZ `v0.3.0-rc1`. The browser and React Native connect kits are planned, not shipped.

## Links

- Docs: [TypeScript client](https://logos-kit-docs.vercel.app/docs/sdk/client), [Transactions](https://logos-kit-docs.vercel.app/docs/concepts/transactions)
- Source: [logos-kit/logos-kit](https://github.com/logos-kit/logos-kit/tree/main/packages/client)

## License

MIT OR Apache-2.0
