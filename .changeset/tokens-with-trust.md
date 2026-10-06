---
'@logos-kit/protocol': minor
'@logos-kit/client': minor
---

`lez_getTokens` (client: `getWalletTokens`): the tokens on a shared account,
each with its trust tier (`verified` on the Logos Kit list, `added` by the
user, or `unknown`), name, symbol and decimals when known. Spam and tokens the
user hid are never listed. Same grants as `lez_getBalance`.
