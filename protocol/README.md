# @logos-kit/protocol

**LWS-0**, the Logos Kit wallet protocol for the Logos Execution Zone: the methods a dApp calls, the Basecamp intents it opens, their parameters and results, error codes and constants. Shipped as TypeScript types, JSON Schema and test vectors, so a wallet or an app in any language can implement it.

```sh
npm install @logos-kit/protocol
# pnpm add @logos-kit/protocol  ·  yarn add @logos-kit/protocol  ·  bun add @logos-kit/protocol
```

```ts
import { CHAINS } from '@logos-kit/protocol'
import methods from '@logos-kit/protocol/methods.json' with { type: 'json' }
```

| Entry | Contents |
|---|---|
| `@logos-kit/protocol` | Types, error codes and classes, CAIP-2/10 helpers, constants |
| `@logos-kit/protocol/schema` | The TypeBox schemas |
| `@logos-kit/protocol/schema.json` | JSON Schema for every message |
| `@logos-kit/protocol/methods.json`, `intents.json` | The method and intent catalogue |
| `@logos-kit/protocol/vectors/*` | Encoding test vectors shared with the Rust wallet |

Most apps use [`@logos-kit/client`](https://www.npmjs.com/package/@logos-kit/client), which wraps this protocol.

## Links

- Docs: [Methods](https://logos-kit-docs.vercel.app/docs/reference/methods), [Intents](https://logos-kit-docs.vercel.app/docs/reference/intents), [Errors](https://logos-kit-docs.vercel.app/docs/reference/errors)
- Source: [logos-kit/logos-kit](https://github.com/logos-kit/logos-kit/tree/main/protocol)

## License

MIT OR Apache-2.0
