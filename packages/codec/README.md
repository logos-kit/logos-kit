# @logos-kit/codec

Byte-exact encoding for the **Logos Execution Zone** (LEZ 0.3): borsh, messages, transactions, account ids and u128 amounts, with no `BigInt` and no bignum library. The root entry is QML-safe, so it runs in Node, browsers and Basecamp's Qt engine; its output is checked against vectors from the Rust wallet.

```sh
npm install @logos-kit/codec
# pnpm add @logos-kit/codec  ·  yarn add @logos-kit/codec  ·  bun add @logos-kit/codec
```

## Build calls

```ts
import { nativeTransfer, tokenTransfer } from '@logos-kit/codec'

const pay = nativeTransfer(from, to, '42')          // native LEZ (a whole number: LEZ has no decimals)
const give = tokenTransfer(from, to, token, '250')  // a fungible token from the token program
```

Pass the result to the wallet with `@logos-kit/client`'s `sendCall`; the wallet decodes it again and shows the user what it does before they approve.

## Amounts as strings

u128 amounts stay decimal strings end to end, so nothing is rounded:

```ts
import { add, compare, formatUnits, parseUnits } from '@logos-kit/codec'

parseUnits('1.5', 6)      // "1500000"   (for tokens that define display decimals)
formatUnits('1500000', 6) // "1.5"
// The native token: lepta on the wire, LGO on screen (1 LGO = 10^9 lepta)
formatUnits('1500000000', 9) // "1.5"   (LGO)
parseUnits('2.5', 9)         // "2500000000"   (lepta, for a transfer)
add('1', '2')             // "3"
compare('10', '9')        // 1
```

`@logos-kit/codec/sign` adds BIP-340 signing (Node and browsers; the wallet does its own signing).

## Links

- Docs: [Codec](https://logos-kit-docs.vercel.app/docs/sdk/codec)
- Source: [logos-kit/logos-kit](https://github.com/logos-kit/logos-kit/tree/main/packages/codec)

## License

MIT OR Apache-2.0
