# @logos-kit/protocol

## 0.2.0

### Minor Changes

- `lez_getTokens` (client: `getWalletTokens`): the tokens on a shared account, ([#8](https://github.com/logos-kit/logos-kit/pull/8))
  each with its trust tier (`verified` on the Logos Kit list, `added` by the
  user, or `unknown`), name, symbol and decimals when known. Spam and tokens the
  user hid are never listed. Same grants as `lez_getBalance`.

## 0.1.1

### Patch Changes

- npm-first install instructions in each README (npm, pnpm, yarn, bun). First release through GitHub Actions trusted publishing, with provenance. ([`20f5360`](https://github.com/logos-kit/logos-kit/commit/20f53602f56df72e05ed0b4c8cc1fbd9f9c09eed))

## 0.1.0

### Minor Changes

- First public release: the LWS-0 wallet protocol, the LEZ 0.3 codec, the typed client (node reads, wallet actions, Basecamp transport) and the Tray design tokens. Built against LEZ v0.3.0-rc1; preview (0.x).
