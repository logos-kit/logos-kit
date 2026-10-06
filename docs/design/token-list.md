# Token list, logos and metadata (stage D)

LEZ stores very little about a token on chain. A fungible definition is `{name, total_supply, metadata_id?}` and a collection is `{name, printable_supply, metadata_id}` (`vendor/lez/lez/programs/token/core/src/lib.rs`). There is **no symbol, no decimals and no logo** on chain, and anyone can create a token called "USDC" for almost nothing.

So Logos Kit ships three things, the same way MetaMask and Phantom do:

1. **A token list** that says which tokens are Verified, with their symbol, decimals and logo.
2. **Bundled logos** for those tokens, so the wallet never fetches an image for them.
3. **A metadata JSON format** for the `uri` a token or collection points to, which LEZ leaves undefined.

How tokens are ranked and shown is in [`ux-tokens-nfts.md`](ux-tokens-nfts.md) §5. The reasons are in [`../dev/lp0001-decisions.md`](../dev/lp0001-decisions.md) (D6–D10).

---

## 1. Files

| Path | What |
|---|---|
| `registry/tokens/lez-testnet.tokenlist.json` | The list for the testnet (created in stage T with LKT and the Pass) |
| `registry/tokens/logos/<address>.png` | One logo per entry, named by Token ID |
| `registry/schema/tokenlist.schema.json` | The list's JSON Schema |
| `registry/schema/token-metadata.schema.json` | The metadata JSON Schema |

The engine embeds the list at build time, so the CLI, the Basecamp core module and the SDK read the same entries. The wallet UI module bundles the logos in its `qrc`. Both modules are signed `.lgx` packages, so the list is signed by the release key; there is no remote refresh in v0 (D8).

## 2. The list format

It is the [Uniswap Token List](https://github.com/Uniswap/token-lists) shape, which wallets, explorers and editors already understand: `name`, `timestamp`, `version {major, minor, patch}`, `tags`, `tokens[]`.

**One deviation.** Uniswap's `chainId` is an EVM integer. LEZ networks are CAIP-2 strings (`lez:testnet`), so each token carries `extensions.chain` instead and has no `chainId`. CoinGecko's Solana list deviates the same way (it sets `chainId: null`).

```json
{
  "$schema": "../schema/tokenlist.schema.json",
  "name": "Logos Kit",
  "timestamp": "2026-10-06T00:00:00Z",
  "version": { "major": 1, "minor": 0, "patch": 0 },
  "tags": {
    "sample": { "name": "Sample", "description": "Sent with test LGO so new users see a token arrive." },
    "pass": { "name": "Logos Kit Pass", "description": "The free membership NFT." }
  },
  "tokens": [
    {
      "address": "<LKT definition id>",
      "name": "Logos Kit Test Token",
      "symbol": "LKT",
      "decimals": 2,
      "tags": ["sample"],
      "extensions": { "chain": "lez:testnet", "kind": "fungible" }
    },
    {
      "address": "<Pass collection id>",
      "name": "Logos Kit Pass",
      "symbol": "LKPASS",
      "decimals": 0,
      "tags": ["pass"],
      "extensions": { "chain": "lez:testnet", "kind": "collection", "metadataId": "<metadata id>" }
    }
  ]
}
```

**Field rules**
- `address` is the **definition** account (the Token ID), never a holding.
- `name` must equal the on-chain name byte for byte. CI checks it against the testnet.
- `symbol`: 1–11 characters, letters, digits and `.+-`.
- `decimals`: 0–36. Collections use 0.
- `logoURI` is optional and only for other tools. The wallet ignores it.
- `extensions.kind`: `fungible` or `collection`. A collection entry makes the collection Verified under Collectibles.

**Versions** (Uniswap's rules): major when an entry is removed or its address changes; minor when an entry is added; patch for anything else (a logo, a description).

## 3. Logos

- PNG, 256 × 256, square, transparent background preferred, under 64 KB.
- Named `registry/tokens/logos/<address>.png`.
- The wallet draws it in a circle mask at 36 px (lists) and 64 px (details), so keep the mark inside the centre 80%.
- A token with no logo gets the **initials circle**: 1–3 characters from the symbol (or name) with everything except `A–Z a–z 0–9` removed, ink on a tone picked from the Token ID, so it is the same on every device. Unknown tokens always get the initials circle, even if they have an image, because loading it would tell the token's creator your IP address (D6).

## 4. Metadata JSON

LEZ's `TokenMetadata` holds `standard` (`Simple` or `Expanded`), `uri`, `creators` and `primary_sale_date`. The JSON at `uri` is ours to define (`registry/schema/token-metadata.schema.json`):

| Field | Simple | Expanded | Notes |
|---|---|---|---|
| `name` | required | required | ≤ 64 characters |
| `symbol` | fungible | fungible | ≤ 11 characters |
| `decimals` | fungible | fungible | 0–36 |
| `description` | ✓ | ✓ | ≤ 1000 characters, plain text |
| `image` | ✓ | ✓ | a bare Logos Storage CID (`zDv…`) or an `https://` URL |
| `external_url` | ✓ | ✓ | `https://` only; shown as text with an explorer-style "Open" |
| `attributes[]` | — | ✓ | `{trait_type, value, display_type?}`, up to 64 |
| `animation_url` | — | ✓ | recorded and shown as a link; not played |

- **Immutable.** A definition can't change after creation, and its metadata account can't either, so Collection Studio asks the creator to confirm the art is final.
- **Why a bare CID, not `lgs://…`:** Basecamp's scaffold already uses `lgs` as an alias for something else, and a bare CID is unambiguous (D10).
- **Where the wallet reads it from, in order:** the token list → the on-chain name → this JSON. The JSON is fetched only for Verified and Added tokens, and only from Logos Storage unless the user turned on web images; never for private holdings.
- **Image limits:** PNG, JPEG, WebP or the first frame of a GIF, up to 5 MB and 4096 × 4096. The engine decodes and re-encodes it as PNG before any QML sees it. SVG is never drawn.

## 5. Adding a token to the list (community PRs)

1. Add an entry to `registry/tokens/lez-testnet.tokenlist.json` and its logo.
2. Bump the minor version and the timestamp.
3. CI (`registry` job, stage T) checks: the schema; the logo's size and format; that `address` decodes on the testnet as a definition of the stated `kind`; that `name` matches on chain; that no symbol or name is confusable (UTS-39) with an existing entry or with LGO.
4. A maintainer merges; the next wallet release carries it.

Being on the list means "this is the token its creator says it is", not that it is safe or valuable. The wallet says so on the token page.
