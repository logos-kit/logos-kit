# Decision log: tokens, NFTs, private proofs and the Market

Each entry records what we chose, why, what else we considered, and the evidence. It feeds the "Approach" section of the λPrize write-ups (LP-0021 and LP-0001), which ask for alternatives considered and what failed. Source paths are in this repo; `vendor/lez` is LEZ v0.3.0 (`db66590`).

Status words: **decided** (built or about to be), **spike** (decided, pending a spike in stage N1 that can overturn it), **open**.

---

### D1. One combined launch
**Decided.** The wallet ships publicly only once it has Phantom-grade tokens, NFTs, private membership proofs and the Market. Release 0.3.0 went to the catalog quietly (no announcement) so nobody installs the earlier mismatched set.
**Why:** the maintainer's call (2026-10-06). One launch, one story, one adoption clock for both prizes.

### D2. A token is its definition ID
**Decided.** Identity, trust, hiding and pinning are keyed by Token ID (the definition account). Names and symbols are display only; when two tokens share a name the UI shows the short Token ID.
**Why:** names are unvalidated and not unique on chain (`TokenDefinition::Fungible { name, … }`). A live Jupiter search for "USDC" returned at least seven tokens with that literal symbol (`docs/design/research/token-ux-research.md` §2b).

### D3. Fungible sends go to the recipient's ATA
**Decided.** The wallet sends tokens to `ATA(recipient, definition)`, creating it in the same transaction when missing (no recipient signature needed). It preflights the recipient's own slot only for native LGO and legacy-style sends.
**Why:** a LEZ account has one token slot (`account.rs:142-159`); a second, different token sent to it fails (`transfer.rs:94-104`). ATAs are PDAs anyone can create (`ata/src/create.rs:45-62`), so any account can hold any number of tokens. This is Solana's associated-token-account model, which Phantom uses.
**Alternatives:** (a) keep sending to the own slot and show "they can't receive this token": fails the "anything sent to you shows up" bar. (b) Ask recipients to pre-create holdings: a step no other wallet asks for.

### D4. A squatted own slot is hidden and explained, not "cleared"
**Decided (revised in stage T).** When an unknown token sits in an account's own token slot, the wallet hides it like any unknown token and its details say why it's there. There is no "Clear slot" action.
**Why:** `InitializeAccount` signed by the owner does re-initialise the slot (`programs/token/src/initialize.rs:41-49`, upstream test `tests.rs:514`), but only to a zero-balance holding *of a definition*: the slot stays occupied, and LEZ has no instruction that releases it. So "clearing" would remove the junk balance but free nothing. Since Logos Kit routes every public token send to the recipient's token account (D3), the own slot only matters for stock LEZ wallets that send into it, and for creating a new token into that account (which needs an empty slot; the create sheet only offers accounts whose slot is free).
**Alternative rejected:** re-initialising the slot to a token the user expects (say LKT): it helps only with stock-wallet sends of that one token, and would surprise users.

### D5. Discovery by block scan (`chain-index`), not an indexer
**Decided.** A new crate scans blocks from the wallet's birthday, matches token and ATA instructions and deshield deposits against the user's accounts and `ATA(own, D)`, records every definition seen, and then follows the chain with one `getBlockRange` (≤ 1024 blocks) per sync.
**Why:** LEZ has no "tokens by owner" RPC, and the public testnet exposes the sequencer only (no indexer). Every token write is visible in its block (`execution_state.rs:131-132`). Measured: about 27 MB and 30 s for the whole testnet chain today.
**Alternatives:** the indexer's `getTransactionsByAccount` would be cheaper but isn't reachable on the testnet; an upstream "accounts by owner" RPC is listed as an issue to file (stage L).
**Reused by:** NFTs, the proof verifier (roots and nullifiers), the Market (listings), testimonial evidence and the Wall.

### D6. Unknown tokens never load images or metadata
**Decided.** Metadata JSON and images are fetched only for Verified and Added tokens. Unknown and Spam tokens show the initials circle.
**Why:** the token's creator controls that server; a fetch tells them the user's IP address and that the wallet is active. MetaMask's privacy copy says the same about token images (research §1, "Privacy").

### D7. The token list uses the Uniswap Token List shape, with `extensions.chain`
**Decided.** `registry/schema/tokenlist.schema.json`. Uniswap's `chainId` is an EVM integer, so it's replaced by a CAIP-2 `extensions.chain` (`lez:testnet`).
**Alternatives:** (a) Trust Wallet's per-token `info.json` folders: more files, no list-level versioning. (b) A bespoke format: no tooling. CoinGecko's Solana list also breaks `chainId` (it uses `null`), so the deviation has precedent.

### D8. The list ships inside the signed modules; no remote refresh in v0
**Decided.** The engine embeds the list at build time and the UI bundles the logos, so both are covered by the `.lgx` signature. A new entry reaches users with the next release.
**Why:** no extra network call, no second signing scheme, no server to run. Basecamp's QML sandbox can't load remote images anyway (`RestrictedUrlInterceptor.cpp:126-210`).
**Later:** a detached-signature remote list if the release cadence turns out too slow.

### D9. Totals count LGO, Verified and Added only; no fiat
**Decided.** The testnet has no prices, so the header shows the LGO balance and the list sorts by balance, then name.
**Why:** counting Unknown tokens would let anyone inflate a user's "total" (Rabby and MetaMask exclude unverified assets the same way; research §3a, §6).

### D10. We define the metadata JSON; images are bare Logos Storage CIDs or https URLs
**Decided.** `registry/schema/token-metadata.schema.json`: `Simple = {name, description, image, external_url}`, `Expanded` adds `attributes[]` and `animation_url`; fungibles may add `symbol` and `decimals`.
**Why:** LEZ's `TokenMetadata` stores only `{standard, uri, creators, primary_sale_date}` and no JSON format exists anywhere upstream. Field names follow the common NFT conventions so other tools read them. A bare CID avoids `lgs://`, which clashes with Basecamp's scaffold alias. Metadata can't change after creation, so Studio asks for an "art is permanent" confirmation.

### D11. No membership oracle
**Decided.** "Not a member", "held only publicly", "listed" and "declined" all give the app the same answer (`4001`), and only after the user closes the prompt.
**Why:** otherwise an app with only `request_proof` could learn whether the user holds an item from how fast or how differently the wallet refuses (found in the plan red-team, 2026-10-06).

### D12. Proofs travel by handle, in parts
**Decided.** An approved proof request returns a handle; the app polls `lez_getProofStatus(handle)` and fetches `lez_getProofBundle(handle, part)` in ≤ 60 KB parts, readable only by the requesting module. A finished bundle is kept for 10 minutes.
**Why:** intent payload strings are capped at 64 KB (`protocol/src/schema/primitives.ts:35-40`) and the shell drops an intent after 10 minutes (`IntentBroker.cpp:17`); a proof is about 225 KB and takes 5–16 minutes.

### D13. Every proof needs its own approval
**Decided.** The `request_proof` grant only lets an app *ask*. The user approves each proof in the wallet.
**Why:** LP-0001 asks for separate approvals for proof generation; a standing grant would let an app collect proofs silently.

### D14. Re-proving refreshes the item first; proofs use a random view tag
**Spike N1(a).** A new proof for an item whose earlier proof may still be live first does a private self-transfer to a fresh vault, which spends the old commitment, so older proofs fail as `stale`. Proof outputs carry a random view tag rather than the key pair's tag, so two proofs can't be linked by it.
**Why:** freshness and replay resistance without an on-chain registry of issued proofs; unlinkability across proofs.

### D15. Design A for the gate (private transaction calling `programs/gate`)
**Spike N1(a), fallback B.** The proof is a private LEZ transaction in which the gate program `inspect`s the vault's holding (`NftPrintedCopy { definition_id == collection, owned }` or the master) and writes an attestation into a PDA keyed by the nullifier, so a valid proof always applies.
**Evidence:** a program can `Plan::inspect` another program's shard read-only inside a private transaction (`program/mod.rs:739-751`).
**Fallback (B):** a standalone membership guest composed with `env::verify` (LP-0005's pattern).

### D16. Vault identifiers and opaque handles
**Decided.** A private account is one key pair plus its vaults. Vault identifiers are `PRF(vault seed, i)` (256-bit), registered locally before submitting and rediscovered on restore. Apps only ever see opaque handles, never vault IDs (pattern: `private_handle`, `service.rs:1965`).
**Why:** one NFT holding per account means each private NFT needs its own account; handles keep them unlinkable from the app's side.

### D17. The Pass is printed publicly, then made private
**Decided.** The drip prints the Pass to the user's public ATA; the wallet then offers "Make private". Copy: "Claiming is public; proving later is private."
**Why:** the drip runs in 128 MB and can't build proofs.

### D18. Media goes through the engine; no SVG
**Decided.** The engine downloads (Logos Storage first; https only when the user turns on web images; never for private holdings), checks limits, decodes PNG/JPEG/WebP/first GIF frame and re-encodes as PNG. QML never sees SVG or a remote URL. Other apps draw NFTs with the SDK's `NftImage`, fed by the engine.
**Spike N1(c):** how the PNG reaches QML in the wallet and in another app's sandbox, on macOS and Linux, after a module update.

### D19. Spam rules are local heuristics
**Decided.** Links or handles in the name, airdrop bait words, UTS-39 lookalikes of a Verified name or of LGO, bidi/zero-width/control characters, names over 32 characters (`ux-tokens-nfts.md` §5).
**Why:** the testnet has no scanning service (no Blockaid, no price feeds). These are the rules Phantom and Rainbow document for their own auto-hide (research §2, §3b).

### D20. Market v0: fixed-price escrow, public seller, private buyer
**Spike N1(f).** One escrow PDA per listing, price in LGO, list → buy → cancel with atomic release. Buying from a private account lands the item in a fresh vault. Listing spends the commitment, so outstanding proofs end. A racing second buyer must fail at apply time and pay nothing.
**Gate:** if a private buy can't fit one transaction, v0 ships public buying, or the Market waits. It never blocks either prize.

---

## Open

- **O1. Proving inside Basecamp.** Proving runs in Basecamp's process today, so running out of memory kills Basecamp. Stage W adds a memory check and a low-memory mode; moving proving to a child process is the goal if the module host allows it.
- **O2. Anonymity-set size.** The proof prompt shows "one of about N private holders". N comes from `chain-index` counting private holdings per collection, which needs the spike to confirm what is countable.
