# Logos Kit — the full build for one combined launch (LP-0021 wallet + LP-0001 NFTs/private gating + Market)

Written 2026-10-06 after six research passes (code map, LEZ token internals, MetaMask/Phantom/Rabby/Rainbow token UX, Refero screens, README patterns, a red-team of the previous plan). It supersedes `PLAN-LP0001.md` v1/v2.

Self-contained. A fresh session executes it from here plus `logos-kit/PROGRESS.md`. Repo copy: `logos-kit/docs/dev/PLAN-LP0001.md`.

---

## 1. Context and decisions

**What we have**
- Logos Kit is our λPrize **LP-0021** entry ($20k): a LEZ wallet (Basecamp module + CLI) plus a Wallet Provider SDK.
- It works end to end on the **official testnet 0.3** (`https://testnet.lez.logos.co`); every route was proven with real proofs in blocks 11969–12004.
- PR [logos-kit/logos-kit#4](https://github.com/logos-kit/logos-kit/pull/4) holds the Ledger redesign, the fee display, the approval fixes and release 0.3.0. CI is 4/4 green.

**User decisions**
1. **ONE combined public launch.** The wallet ships *with* Phantom-grade tokens, NFTs, private gating (LP-0001, $5k) and a Market. Promotion starts only after everything is built and the user has tested it.
2. **Scope of this plan = what we control:** code, UX, docs, CI, demo, release, submission artefacts. Promotion and adoption are handled later with the user. This plan builds only the *enablers*: the Wall, Studio, the template, the evidence exporters.
3. **No deadlines.** Do a very good job. Never quote dates or durations.
4. **UX is first-class.**
   - Tokens behave like MetaMask/Phantom: anything sent to you shows up, you can add a token by ID, logos show, spam stays out of the way.
   - Cover everything a top wallet does, including what the user didn't think to mention.
5. **One design**, grounded in Refero and built in the real product (Ledger system, light and dark). No option canvases.
6. **CLI parity:** every feature works from the CLI and from the app.
7. The **Logos Kit Pass** NFT is **free**: one per wallet, claimed in the Faucet app, never tied to a testimonial.
8. **Market v0 is in** (escrow, private buying). Logos itself has an open "[RFP] Basic Marketplace" (ecosystem#124), a marketplace sample-app scoping issue (#134), and #233 lists "NFT wallet + marketplace: LP or RFP" as an open decision.

**Prize rule (fact, not a target):** adoption counts across ≥ 2 months (LP-0021 ≥ 30 testimonials a month; LP-0001 ≥ 20 gated actions a month). The clock starts at launch.

## 2. Where LP-0021 stands (35 criteria)

| Status | Count | Rows |
|---|---|---|
| **MET** | 22 | F1–F8, U1–U4, U7, R1–R4, S1–S3, S5, SR1 |
| **PARTIAL** | 5 | U5 source verification · U6 UX quality · P1 responsiveness · S4 README · SR5 evaluator demo |
| **NOT MET** | 8 | A1–A5 adoption · SR2 narrated video · SR3 evidence pack · SR4 FURPS write-up |

The 8 NOT MET rows are adoption and paperwork. They come after launch, except SR2 (video) and SR4 (write-up), which are scheduled in stage L.

**Corrections to the audit** (verified on `ui/wallet-v3`):
- **U5:** the native-transfer row, approvals reading the rebuild cache, and the "Source mismatch" label are already done (`feed5ef`).
- **U5 still open:**
  - app-proposed native sends show no Program row (`ApprovalView.qml:174-176`);
  - the CLI and Basecamp keep separate `verified.json` folders;
  - there is no user registry.

## 3. Verified facts that shape the build

**Token model** (LEZ v0.3.0 `db66590`, `vendor/lez`)
- **Fungible definitions:** `{name, total_supply, metadata_id?}` (`token/core/src/lib.rs:88-93`). There is **no symbol and no decimals on chain**, names are unvalidated, and nothing on chain can change after creation.
- **Metadata:** `TokenMetadata{standard Simple|Expanded, uri, creators}`. No JSON schema exists anywhere, so **we define it**.
- **One token slot per account** (`account.rs:142-159`):
  - A *second, different* token sent to the same account **fails** (`transfer.rs:94-104`).
  - Stock wallets, and ours today, send into the recipient's own slot.
  - A 0-balance holding never leaves the slot.
- **ATAs:** address = `PDA(owner, definition, token program)`. Anyone can create one or deposit into one without the owner's signature (`ata/src/create.rs:45-62`, `transfer.rs:63-68`). This is the Solana/Phantom model.
- **Discovery:**
  - No RPC lists tokens by owner.
  - The live testnet exposes the **sequencer only**, not the indexer.
  - Every token write is visible in its block (`execution_state.rs:131-132`).
  - **A block scan works:** about 27 MB and 30 s for the whole chain today; then one `getBlockRange` (max 1024 blocks) per sync.
- **Private receipts** are found by note decryption. Each one becomes a new private identity: a "vault", key pair plus identifier, up to 2^256 per key pair.
- **Spam is nearly free:**
  - anyone can create "USDC" and deposit it into empty slots or ATAs;
  - a junk token can squat your empty own slot;
  - anyone holding your receive code can mint unlimited private junk identities.

**NFT model**
- Collection = `TokenDefinition::NonFungible{name, printable_supply, metadata_id}`.
- Items are `NftPrintedCopy{owned}` prints with no serials; metadata is **per definition**; one holding per account.
- Token id = the holding account, which changes on transfer.

**Proofs**
- Inside a *private* transaction a program can `Plan::inspect` another program's shard read-only (`program/mod.rs:739-751`).
- No receipt verification inside public transactions.
- Proving takes 5–8 min and 4–10 GB, **inside Basecamp's process**.
- Rust `Receipt::verify` works off-chain; risc0 also ships a wasm verifier.
- No RPC for root history or spent nullifiers.
- The sequencer accepts fake receipts in dev mode.

**Basecamp**
- **QML sandbox:** images load only from `qrc:` or files under the module's own install dir (`RestrictedUrlInterceptor.cpp:126-210`). No network, no `data:`.
- **Intents:** payload strings are capped at **64 KB** (`protocol/src/schema/primitives.ts:35-40`), and the shell drops an intent after **10 min** (`IntentBroker.cpp:17`). A proof is about 225 KB and takes 5–16 min.

**Logos Storage**
- `storage_module` is a core dependency: `uploadUrl`/`downloadToUrl`, CIDs, a local node on `logos.test`.
- It is not private by default (`isPrivate`, `advertise` flags).
- The first fetch needs the uploader's node to be reachable.

## 4. Product design (decisions, built in the stages below)

### 4.1 Tokens, Phantom-grade (stage T)

- **Identity.** A token is its definition ID. Never match on name or symbol. When two tokens share a name, show the short definition ID.
- **Receiving many tokens:**
  - The wallet **sends fungible tokens to the recipient's ATA** (auto-created, no recipient signature), so any account can hold any number of tokens.
  - It preflights the recipient's own slot only for native and legacy sends.
  - Private recipients: each private token or NFT lands in its own **vault** under the recipient's keys.
- **Discovery: the `chain-index` crate,** shared later by NFTs, the proof verifier, the Market, evidence and the Wall.
  - An incremental block scan from the wallet's birthday.
  - Matches token and ATA instructions and deshield deposits against our accounts and `ATA(own, D)`.
  - Records every definition D it sees, with first-seen block and sender.
  - Restore rescans with a progress bar.
  - Caches definitions instead of re-fetching names every 12 s.
- **Trust tiers:**
  - **Verified:** on our signed, bundled token list in Uniswap Token List schema, with LEZ fields under `extensions`, versioned with semver, and community PRs welcome. Check mark, logo, counts in totals.
  - **Added by you:** imported by the user; a chip; shown in the main list.
  - **Unknown:** received but neither verified nor added. Shown in a collapsed **"Unknown (N)"** section, excluded from totals, with a generated avatar. Phantom's rule: unhiding never raises trust.
  - **Spam:** auto-hidden by local checks:
    - URLs or `@`/`t.me` in the name, or airdrop-bait words;
    - Unicode confusables of a verified name (UTS-39), RTL or control characters;
    - names longer than 32 characters;
    - lookalikes of a verified token.
  - **Hidden by you:** stays hidden and is skipped on later scans.
- **Names, symbols, decimals.** Order of sources: token list → on-chain name → metadata JSON. Metadata is fetched **only for Verified or Added tokens**: a stranger's metadata host would learn the user's IP. If decimals are unknown: "decimals unknown", raw units, and the user may set 0–36 on import.
- **Logos.**
  - Verified tokens: bundled PNGs in the UI module (`qrc`).
  - Added tokens: the metadata `image`, from a Logos Storage CID, or from the web only if the user has turned web images on.
  - The engine decodes and re-encodes the image to PNG; spike N1(c) settles how it reaches QML.
  - Fallback: a monochrome ink circle with 1–3 sanitised initials, its tone derived from the definition ID (Family pattern, Ledger colours).
- **Home list.**
  - Order: LGO first, then pinned tokens, then Verified/Added by balance (by name when there's no price; testnet has none).
  - Zero balances hidden except LGO and pinned tokens.
  - The list ends with a "Hidden · Unknown (N) ›" row.
  - A "Manage tokens" link: search, a toggle per token, Hidden and Spam tabs, pin, and "Add a token".
- **Add a token by ID** (Family "Add Address" tray, Phantom form):
  1. Paste or scan the ID.
  2. Validate: the account exists, the token program owns it, and it decodes as a definition. Plain errors: "This is a holding account — paste the token's definition ID", "This is a personal address".
  3. A skeleton row while it looks up.
  4. An "Exact match" preview: name, kind, supply, metadata, your balance, trust status.
  5. Decimals field.
  6. Inline warning: "Anyone can create a token, including fake copies." A hard warning if it imitates a verified token.
  7. Add → toast → the row appears in the list.
- **Token detail** (Glow sheet, no chart on testnet):
  - Big balance; Send and Receive tiles.
  - Activity for this token, with an empty state.
  - Definition ID and holding ID, each with copy and an explorer link (engine `open_explorer`).
  - Decimals and their source; supply; metadata (standard, URI, creators).
  - A trust panel; the ⋯ menu has Pin, Hide, Copy and Explorer.
- **Create a test token in the app:** name, supply, holder (public accounts with LGO for the fee). Preflight the holder's slot; label the definition account; select the holder afterwards.
- **Sample token:**
  - When a user claims test LGO, the drip also sends **100 "Logos Kit Test Token" (LKT)** to their ATA. LKT is on the verified list with a logo.
  - So every new user sees auto-detection and a logo in their first minute.
  - It has its own ledger and rate limit.
- **Send safety:**
  - Reject a definition or holding ID used as a recipient.
  - Lookalike warning: same first 4 and last 4 characters as a past address, different middle.
  - First-time-recipient note.
  - "Will create their token account" note.
  - Decimals enforced.
  - **MAX leaves the fee.**
  - First send of an Unknown token shows an extra confirm row (UGLYCASH warning-pill pattern).
- **Receive:** a Coinbase-style line saying what this address accepts: LGO, any LEZ token, NFTs. The private code shows its "Code ends XX-XX" fingerprint, and Send shows the same fingerprint when you paste a code.
- **Private spam:** unsolicited private identities are grouped under Unknown, never listed as accounts.
- **Squatted own slot:** detected, with a "Clear this slot" action (re-initialise with your signature) explained plainly.
- **CLI parity:** `token list [--all|--hidden|--unknown]`, `token add <def> [--decimals]`, `token hide|unhide|pin <def>`, `token info <def>`, `token create`, `faucet --token`.

### 4.2 Accounts and vaults
- A **private account = one key pair plus its vaults.** Balances and counts add up across vaults. The account switcher shows "N vaults" when expanded.
- **Vault identifiers:**
  - generated as `PRF(vault seed, i)`, 256 bits;
  - registered locally *before* submitting;
  - found again on restore; senders' identifiers are found by decryption.
  - A vault whose NFT has left (`owned:false`) is reused for the same collection.
- **Apps only ever see opaque handles**, never vault IDs (pattern: `private_handle`, `service.rs:1965`).

### 4.3 NFTs (stage N2)
- **Collectibles tab:**
  - collections grouped, with counts, expandable into 2-column tiles (Family);
  - collection page (Glow);
  - NFT detail: square media, collection card, mono rows (Collection, Holding ID with an explainer, held in public / private vault / listed, metadata source, standard, creators, printable supply and prints left for a master);
  - action tiles **Send · Make private · Prove · Sell**.
- **Missing media:** a placeholder with collection + holding ID + a reason (Web images off / Unreachable / Invalid metadata / Too large / Unsupported type) + Refresh. Never hidden.
- **Media handling:**
  - The engine downloads (Logos Storage first; `https://` only when the user opts in, and never for private holdings) and decodes PNG/JPEG/WebP/first GIF frame within limits, then re-encodes to PNG.
  - **No SVG reaches QML.**
  - Other apps get images through the SDK `NftImage` component (engine-decoded cells), because each app's sandbox only reads its own folder.
- **Metadata JSON (we define it):**
  - `Simple = {name, description, image, external_url?}`; `Expanded` adds `attributes[]` and `animation_url`.
  - `image` is a bare Logos Storage CID (not `lgs://`, which clashes with the scaffold alias) or a URL.
  - Metadata is **immutable**: Studio shows an "art is permanent" confirmation.
- **Sends:**
  - public NFTs go to the recipient's ATA;
  - private-code sends go to a fresh vault;
  - private→private sends are unlinkable;
  - the sheet says "Single item" or "Entire master edition: they can print N more".
- **Spam:** unverified collections sit behind "Unknown (N)"; Hide moves a collection to a visible "Hidden (N)" section.

### 4.4 Private membership proof (stage N4; the N1 spike confirms design A, otherwise B)

**Design A.** The proof is a private LEZ transaction calling our `gate` program.
- The gate `inspect`s the vault's holding: `NftPrintedCopy{definition_id == collection, owned}` or the master.
- It writes an attestation `{collection, context, expires_at, submission "LP-0001/logos-kit", optional payload, optional public author}` into a **per-action PDA keyed by the nullifier**, so `apply` never fails for a valid proof.

**Transport**
- The request returns a **handle** when approved.
- Then `lez_getProofStatus(handle)` and `lez_getProofBundle(handle, part)` (≤ 60 KB parts, readable only by the requesting module).
- This avoids the 64 KB intent cap and the 10-min intent timeout.

**Approval and privacy**
- **Every proof needs its own approval.** The `request_proof` grant only allows *asking*.
- **No membership oracle:** "not a member", "held only publicly", "listed" and "user declined" all return the same response, after the prompt closes.
- **Random view tag** on proof and refresh outputs, so a wallet's proofs can't be linked by its key pair's tag.
- **Anonymity set:** the prompt shows "one of about N private holders" and warns when N is small.

**Freshness**
- `expires_at = start + ETA×1.5 + window`, judged against the latest block's timestamp on both paths.
- **A new proof for the same NFT first refreshes it:** a private self-transfer to a fresh vault spends the old commitment, so older proofs fail with `stale`. The prompt shows the extra time and offers another NFT from the same collection if the user has one.
- An **issued-bundle ledger** lets the wallet adopt the outputs when a dApp submits a bundle, so the NFT never "vanishes".

**Verification and rejection reasons**
- On-chain: submit the bundle.
- Off-chain: `gate-verify` (Rust, npm wasm, a `logos_kit_gate_verify` core module for QML apps).
- Shared reasons: `malformed`, `bad_receipt`, `dev_receipt` (fake receipts always rejected off-chain), `wrong_program`, `wrong_collection`, `not_member`, `wrong_context`, `expired`, `consumed` (this bundle landed), `stale` (a newer proof or a transfer), `unknown_root`; plus `chain_unavailable` and `index_syncing`, which aren't verdicts.
- One vector table records the on-chain outcome next to the off-chain one.
- Roots and nullifiers come from `chain-index`, which rebuilds the commitment tree from genesis and shows progress. The verifier trusts its RPC; that assumption is documented.

**Distinct accounts for adoption:** the Wall may carry a **public author** the user picks. It is approved separately and is never the holding account.

**Design B (fallback):** a standalone membership guest composed into a private transaction via `env::verify` (LP-0005's pattern).

### 4.5 Capabilities and permissions (stage N3)
- **New capabilities:**
  - `request_proof` (session-level, not keyed to an account);
  - `enumerate_nfts` per account, with a separate private tick;
  - `check_membership` (yes/no for one collection);
  - NFT transfer proposals use opaque handles via a `lez.nft.transfer` intent.
- **Proof-only session:** `getSession` returns `{accounts: [], grants: {request_proof}}`. `lez_getCapabilities` advertises `nfts` and `membershipProof{typicalSeconds, maxValidity}`. Protocol bumps to 0.2.0; the change is additive.
- **Grants** record `granted_at`, `last_used_at` and a local log of shared proofs.
- **Connected apps:** a row per capability with its plain-language disclosure; revoke one or all; last used.
- **Capability matrix:** gains *Requires* and *Discloses* columns, generated from protocol annotations that the wallet copy also uses.
- **Privacy fixes:**
  - `granted_accounts`/`session_for` must not reveal accounts that only have a proof grant (`service.rs:1643-1725`);
  - revoke per capability (`engine.rs:858`);
  - the connect sheet honours the capabilities the app asks for (`IntentView.qml:125`);
  - apps may propose private NFT sends through handles (`service.rs:1148`);
  - SDK `transfer()` must use the NFT kind (`facade.ts:233`);
  - `public_invariant` must cover NFTs (`engine.rs:1398-1423`).

### 4.6 Market v0 (stage M; decision gate after spike N1(f))
- **Program:** `programs/market`, one escrow PDA per listing, a fixed price in LGO; list → buy → cancel; atomic release.
- **Private buying:** pay from a private account and the NFT lands in a fresh vault. The seller is public in v0, and the List sheet says so.
- **Proofs:** listing spends the commitment, so outstanding proofs end. A listed NFT can't prove.
- **Racing buyers:** the second buyer fails at apply time and is charged nothing (the spike must confirm).
- **Listings** come from `chain-index`; the collection page shows the floor price.
- **Supporting pieces:** decoders for list/buy/cancel (LP-0021 U4 effects), reproducible build, immutable deploy, a registry entry, a place in the `guest-repro` matrix.
- **CLI:** `market browse|list|buy|cancel`.
- **App:** a Market Basecamp app; the wallet builds private buys.
- **Gate:** if a private buy can't fit in one transaction, v0 ships public buying, or the Market waits. Either way it never blocks the prizes.
- **Out of v0:** auctions, offers, royalties.

### 4.7 The Pass
- The drip runs with `mem_limit 128m` and **can't prove**. So the Pass is printed to the user's public ATA, then the wallet offers "Make private".
- Copy says: "Claiming is public; proving later is private."
- Supply is at least 10,000. The art is final before creation because metadata can't change.
- Stored on Logos Storage, with a seeding node on agari-box. That node is disclosed and optional.

### 4.8 Wallet-wide UX fixes (stage W; from the code map)
1. **First run:** open on the funded public account, not the empty private one (`Store.qml:181-186`, `Onboarding.qml:261-271`).
2. **Activity:**
   - show **incoming** payments (via `chain-index`);
   - keep history across restarts (`engine.rs:42`);
   - token names instead of IDs (`TxRow.qml:25`);
   - app display names (`TxRow.qml:33`).
3. **Explorer button** on results and token or NFT detail (`ui_openExplorer`).
4. **Receive copy** no longer over-promises (`ReceiveView.qml:71`); show the code fingerprint on Send (`SendFlow.qml:57`).
5. **Private accounts explained** in one sheet. The "Test LGO" tile on a private account shows the fund → shield → 5–8 min path up front.
6. **Human errors:** a catalog that maps engine errors to plain copy in LGO with short IDs (`service.rs:1228`, `tx.rs:565`).
7. **MAX** subtracts the fee cap (`SendFlow.qml:83`, `tx.rs:556`).
8. **Settings:**
   - change password (`ui_changePassword`);
   - add a network (`ui_addZone`);
   - encrypted backup export and import;
   - show the faucet host;
   - plain-language permission names.
9. **The welcome screen** hides "Local" behind an Advanced toggle (`Onboarding.qml:102`).
10. **App-proposed native sends** show "Native transfer · Built into LEZ".
11. **Default names** for every new account; token-definition accounts are hidden from the switcher.
12. **One proof-time figure** everywhere (README, ApprovalView, docs). A disabled tile explains why it's disabled.
13. **First launch:** a cold-start progress state, since Basecamp's own startup takes 16–40 s.
14. **Proving robustness:**
    - check free memory first and offer a low-memory mode (po2 18);
    - clear states for out of memory, timeout, restart during a proof, queued, cancelled;
    - proving moves to a child process if feasible, because it currently runs inside Basecamp and an out-of-memory kills Basecamp.

## 5. Design system and references (ONE design, Ledger tokens, light and dark)

| Screen | Primary Refero reference |
|---|---|
| Home token list, initials fallback, hidden row | Family `d6a80a98` + Family web `f2b7a39b` |
| Manage tokens | Phantom `d9fedd43` (+ Family edit `43c2d253` for pin and muted hidden rows) |
| Add token by ID | Family Add Address `3b483d4a` → `123cc956`; Phantom Watch Address `72367c14` |
| Unverified token | UGLYCASH `220a366b` + `2d23b8bd`; Glow `62104eae` |
| Token detail | Glow `92348324` (+ Family `68bc2123`) |
| Receive | Coinbase `724cf794` (+ Family `bedf856e`) |
| Empty / loading | Family `53520250`, Fuse `b8915d3d`, Phantom `652341ab` |
| Collectibles | Family `53dc227a` |
| Collection | Glow `d5184d95` / `b2496e7b` |
| NFT detail | Glow `37f23934`, `57cace94` |
| NFT send review | Family `358cccaa` + Glow `218e00de` |
| Missing media | Rarible `216dd664` |
| Proof request | Glow `ca153aec`, made distinct (shield kicker; "They'll learn / They won't learn" with literal values) |
| Connected apps | Glow `8ea91cb8` + Apple Health `b91a5b52` |
| Market | Coinbase `be0166cf`, Family `ca3a984a`, Glow `49846bfe` |

**Rules**
- Accents become ink; the only colour role is *warning*, used for Unverified and risk.
- Plain rows, not cards.
- Skeletons pulse in opacity, since Canvas may not paint.
- Untrusted strings render as `PlainText` with length caps.
- Explorer opens via the engine.
- Components come from 21st.dev picks (`docs/design/revamp-picks.md`); new ones are ported the same way.

**Journeys first (stage D):**
- `docs/design/ux-tokens-nfts.md` extends `ux-spec.md` and its §11 error catalog.
- One numbered journey per persona, with every state:
  - **Collector:** first run → tokens → claim Pass → make private → prove → Wall → buy/sell.
  - **Creator:** Studio → upload → create → print → list.
  - **Developer:** template → gating → verify → gate a program.
  - **Judge:** catalog → 10-minute path → `demo.sh`.
- **Wallet level:**
  - the switcher with vaults;
  - activity rows for every event;
  - notifications: received, proof ready or failed, listing sold;
  - offline: cached "as of block N";
  - chain stall, locked wallet, intent timeout;
  - 360/680/1024 widths; keyboard; reduced motion.

## 6. Stages (in order; one branch each; tick only with a passing proof command; every stage lands engine + CLI + GUI + SDK + docs together; the user tries it hands-on after T, N2, N4 and M)

| # | Stage | Scope | Exit proof |
|---|---|---|---|
| **A** | Quiet release 0.3.0 (**ask the user first**) | Merge PR #4. Catalog 0.3.0 for core, UI, testimonial and faucet (`docs/dev/releasing.md`). Clean installs: `e2e/catalog-install.sh` (macOS), `--docker` (Linux on agari-box), `catalog-install-gui.sh`. Redeploy the docs. **No posts.** Add `.claude/` to `.gitignore`; the submission bot fails repos that contain it. | 0.3.0 installs clean everywhere |
| **D** | Journeys + design lock | §5 journeys and state lists, the Refero lock per screen, the token list format and logos, the metadata JSON schema. Decision log `docs/dev/lp0001-decisions.md` (feeds the write-up). | Docs reviewed by the user |
| **W** | Wallet polish (LP-0021) | §4.8 items 1–13. U5: one `verified.json` shared by CLI and GUI, plus a **user registry** in `Meta` (`program add/remove` CLI, a Settings list). A test that `lez_getBalance` on a private account is refused before consent (audit R2). **README rebuilt on the RainbowKit/wagmi pattern** (§7). `demo.sh --testnet` (real proofs, drip balance-poll, explorer links, submission `LP-0021/logos-kit-demo`, private→private + token-from-private steps, run log in `docs/reviews/demo/`). `e2e/tokens.sh` in `e2e.yml`. Measure the `PLAN.md:232-238` budgets into `docs/dev/perf.md`. | `demo.sh --testnet` and `--local` logs committed; CI green; harness walk light and dark |
| **T** | Tokens, Phantom-grade | §4.1 complete. New `crates/chain-index` (block scan, definitions cache, ATA matching, deshield deposits, persisted history, incoming activity). ATA-routed sends. Trust tiers and spam heuristics. Signed token list + bundled logos + image pipeline (after N1(c)). Add-token tray, Manage tokens, token detail, create token, LKT sample drop (drip `/fund-token`), send-safety checks, squatted-slot clear. CLI `token …` parity. SDK: `getTokens` with trust tiers. | `e2e/tokens.sh` extended: a stranger's token appears as Unknown, add-by-ID, hide, ATA receive of 3 different tokens on one account; `qa_tokens.py` walk; user check-in |
| **N1** | Spikes | (a) Gate PoC with a real proof on standalone, random view tag, refresh = self-transfer, time and RAM; (b) off-chain `Receipt::verify` + `chain-index` root/nullifier rebuild equal to `getProofsAndRoot`; (c) images in the wallet *and* another app's sandbox, macOS and Linux, after a module update; (d) `storage_module` dependency install, node start or reuse, CLI upload/download, file picker in the sandbox, limits; (e) Pass print to an ATA, then make private; vault identifiers via PRF; (f) Market escrow PDA authority + private buy in one transaction + racing buyers | `docs/dev/lp0001-spikes.md` (VERIFIED); design A/B and the Market gate decided |
| **N2** | NFT engine + CLI + GUI slice | §4.2–4.3. Collectibles, collection, detail, send, make private, media pipeline, Settings → web images; CLI `nft list/collections/show/send/make-private/create-collection/print` | `e2e/nft.sh` (dev proofs) + one real private→private NFT send; restore finds NFTs; user check-in |
| **N3** | Capabilities, protocol, SDK + GUI slice | §4.5. `pnpm --filter @logos-kit/protocol emit` → `cargo xtask types` → `.lidl` + rust-lib forwarders → conformance fake scenarios (proof pending, declined, expired, stale, consumed) → `just capability-matrix`. SDK facade: `getNfts`, `getCollections`, `transferNft`, `requestMembershipProof`, `getProofStatus/Bundle`, `verifyMembershipProof`; client actions; app `metadata.json` intents. Connect sheet + Connected apps UI | `authz.rs`: a proof-only app gets `accounts: []`, `getBalance`/propose → 4100, a non-member decline is identical to a member decline, every proof needs approval; old apps unchanged |
| **N4** | Gate, proofs, verifiers | `programs/gate` (own workspace, reproducible, adversarial tests for `owned:false`/fungible/wrong owner/collection/context). **Security review (Codex + security-reviewer) before the immutable deploy.** Deploy + registry entry + `verify-program`. Engine proof job (shared prover slot, handle/parts transport, issued-bundle ledger, refresh). `crates/gate-verify` + npm wasm + `logos_kit_gate_verify` module; `lez-gate` helper crate. Proof prompt and progress UI. Crypto write-up drafted. | `gate-agree` CI job (dev receipts both sides) + nightly real-proof agreement; real-proof on-chain gate on the testnet; user check-in |
| **P** | Pass | Final art; metadata on Logos Storage; local storage node for tests, seeding node on agari-box; create "Logos Kit Pass" (supply ≥ 10k) on the testnet; drip prints it; Faucet app "Claim your Pass" | A fresh install claims, makes private and proves |
| **N6** | Apps + template | **Members' Wall:** proof-only connect; off-chain verify shown *before* on-chain posting (valid · what it proves · what it hides); optional author; `consumed` after posting. **Collection Studio:** file picker, upload progress, size limits, metadata form, preview drawn as the wallet draws it, permanent-art confirmation, batch print, share ID. Template gains an NFT gallery + gating snippet | `e2e/wall-app.sh`, `e2e/studio-app.sh`, real Basecamp `e2e/basecamp-apps.sh` |
| **M** | Market v0 | §4.6 + its own security review before deploy | `e2e/market.sh` (list, private buy, cancel, racing buyers) + one real private buy on the testnet; user check-in |
| **N8** | Docs, demo, CI, numbers | Docs pages: `guides/tokens`, `guides/nfts`, `guides/token-gating` (worked example), `guides/verify-proof` (Rust/npm/QML), `guides/gate-your-program`, `concepts/membership-proofs`, `wallet/nfts` (media, storage, limits), `wallet/privacy` (every network call), `reference/benchmarks`, capability → disclosure table. README NFT/proof/media/storage sections. **`demo.sh --nft`:** a headless SDK dApp (Node on `@logos-kit/client`, or a logoscore daemon) requests a proof with only `request_proof`, shows the refusals, prints proving stats (no dev mode, receipt kind, seal bytes, cycles, seconds, peak RSS), verifies off-chain *before* submitting, submits on-chain (`LP-0001/logos-kit`), then shows `consumed` and wrong-context/expired negatives. `e2e.yml` NFT + gate + market; nightly real-proof gate. **Benchmarks:** M-series + a Linux desktop (prove, refresh+prove, low-memory mode), gate and apply-time cycles, `PRIVATE_VERIFY_GAS`, fee 0, verifier first-sync and verify time. Gated-action + testimonial **evidence exporters** (per month, distinct authors, prior activity, submission ID) + daily snapshots | `demo.sh --nft` + `--testnet` logs from a clean clone on macOS and Linux; docs build |
| **L** | Combined release | Catalog 0.4.0 (wallet, Wall, Studio, Market, verify module, faucet, testimonial; Linux + macOS); npm; docs. Codex full review against LP-0021 + LP-0001 (`docs/reviews/lp0001/`). **User hands-on test** (CLI + app) → fix round. **Narrated video** for LP-0021 (required) + an LP-0001 walkthrough. `solutions/LP-0021.md` and `LP-0001.md` drafts (template headings, `- **Repo:**`, `[x]` per criterion, Approach with alternatives and failures, why the Logos stack, Supporting Materials, license, T&C) + `criteria-audit-lp0001.md` + an authorship Q&A. Upstream issues (root/nullifier RPC, accounts-by-owner RPC, storage CLI, sandbox images, intent size, Canvas on Linux), each posted only with the user's OK. Launch post drafts (posted later by the user) | User sign-off → the user runs the launch |

## 7. README (stage W, extended in N8), following RainbowKit, wagmi, viem and Porto

- **Today:** 223 lines and about 13 KB, roughly 3× the reference. It contains internal status tables, sslip hosts and stale versions, and has no step-by-step use.
- **Target:** about 200–260 lines.
- **Root README order:**
  1. **Hero:** theme-aware logo `<picture>`, a tagline of ≤ 10 words, one row of neutral badges (e2e CI, npm client, license MIT OR Apache-2.0, Basecamp catalog, docs), links (Docs · Quickstart · Examples · Catalog · Changelog), and a hero GIF of connect → pick → approve → landed.
  2. `[!WARNING]` testnet-only, unaudited.
  3. One sentence, then 6 bullets.
  4. **Quick start:** Basecamp in 3 steps, CLI, build an app.
  5. **Setup:** requirements table (OS/arch, Basecamp, RAM and time for private proofs, Rust/Nix), install, networks in one paragraph.
  6. **Accounts:** a Basecamp | CLI task table.
  7. **Use it in Basecamp, step by step:** 9 numbered steps with screenshots.
  8. **Use it from the CLI, step by step.**
  9. **Build a Basecamp app.**
  10. **Tokens / NFTs and private proofs / Market** (as they ship).
  11. **Privacy and network calls:** a table of endpoint, why, when, how to turn it off.
  12. **Packages** table, **Examples**, **For λPrize evaluators** (`demo.sh` modes, CI badges, program IDs, a criteria → evidence docs page), Security, Contributing, Community, License (Porto-style dual paragraph).
- **Moves out of the root README:**
  - status → changelog;
  - hosts → `concepts/networks.mdx` and `deploy/README.md`;
  - module builds, repo layout, dev → `CONTRIBUTING.md` and `modules/README.md`;
  - CLI flags → `crates/logos-kit-cli/README.md` and docs;
  - QML API → `sdk/qml/LogosKit/README.md`;
  - program → `programs/testimonial/README.md`.
- **Fix stale package READMEs:**
  - `client` still says rc1 and preview;
  - `codec` says "LEZ has no decimals";
  - `theme` says "Tray";
  - `apps/docs` still has the Fumadocs scaffold README.
- **Assets:** theme-aware logo SVGs, a 1280×640 social banner, the hero GIF, a VHS CLI tape, Ledger screenshots for each step. Every claim is checked against the code.

## 8. Criteria → stage

**LP-0021 (remaining)**

| Row | Fix | Stage |
|---|---|---|
| U5 | App-native row, shared cache, user registry | W |
| U6 | Tokens and wallet polish; non-expert sessions with the user's testers | T, W, L |
| P1 | Measured budgets | W |
| S4 | README | W, N8 |
| SR5 | `demo.sh --testnet` + log | W |
| SR2 | Video | L |
| SR4 | Write-up | L |
| SR3, A1–A5 | After launch (enablers: template, evidence exporter) | — |

**LP-0001**

| Criterion | Stage |
|---|---|
| NFT own/send/receive public + private; grouped display; collection counts; missing media shown | N2 |
| SDK NFT APIs (enumerate, membership, transfer proposals with approval) | N3 |
| Private proof, on-chain and off-chain verification, replay resistance, freshness, both sides agree | N4 |
| Proof via SDK with a prompt; proof request stands alone | N3, N4 |
| Gating mini-app (on-chain with submission ID + off-chain) | N6 |
| Testnet 0.3 deploy with a verified program ID | N4 |
| GUI + CLI cover holdings, transfers, proofs | N2–N4 |
| Catalog, `mkLogosModule`, Linux + macOS | L |
| NFT transfer prompt (single vs collection-wide) | N2 |
| Proof prompt reveals / doesn't; separate approvals | N3, N4 |
| Legible, revocable per-capability permissions | N3 |
| Source verification on prompts (gate, market) | N4, M |
| UX quality | D, N2–N6, user checks |
| Integration guide | N8 |
| Clear proof errors | N4, W |
| Deterministic, documented outcomes | N4 |
| No proof or private enumeration without approval | N3 |
| Privacy against verifier, observer and dApp; assumptions; no trusted setup | N4, N8 |
| Unlinkable private transfers | N2 |
| LP-0021 reliability carried over | done |
| Centralised media optional, disclosed, off for private holdings | N2 |
| Logos Storage upload/download + limits | N1, N2, N6, N8 |
| Proof benchmarks; CU cost | N8 |
| E2E in CI; README; real-proof demo via the SDK; SDK docs with requires/discloses | N8 |
| Write-up, benchmarks, evidence, FURPS, upstream issues | N8, L |
| Adoption: 5 collections, 3 apps, 100 gated actions, 20 + 20 posts | after launch (enablers: Studio, template, Wall, exporter) |

**Submission bot** (`validate-submission.sh`):
- The repo must have LICENSE, README, CI and `demo.sh`, and no `.claude/`, `.cursor/` or similar folders.
- A missing `module.json` is only a warning.
- No SPEL IDL is needed: neither prize text mentions SPEL.
- The PR is titled `Solution: LP-XXXX …` and touches only `solutions/`.
- At most 3 submissions, 1 per week.

## 9. Verification

- **Each stage:** its exit proof; CI green (rust, ts with the capability matrix, e2e incl. tokens/NFT/gate/market, qml-gate, guest-repro for testimonial/gate/market, nightly real proofs); harness walks offscreen in light and dark (`qa_wallet.py`, `qa_tokens.py`, `qa_nft.py`, the Wall, Studio and Market apps); real Basecamp flows.
- **On the official testnet:**
  - a stranger's token auto-appears as Unknown;
  - three tokens arrive in one account;
  - a private→private NFT send;
  - a proof without account access;
  - off-chain verify, then on-chain gate, then `consumed`;
  - a stale proof rejected after a refresh;
  - a private buy.
- **The user's hands-on checks** after T, N2, N4, M and L.

## 10. Risks

| Risk | Answer |
|---|---|
| Design A spike fails | Design B |
| Images in sandboxes | Engine-written PNG cache or cell grid, tested in N1(c) |
| Storage reachability or dependency | Seeding node; tested in N1(d) |
| Proving out of memory kills Basecamp | Memory check, low-memory mode, child process |
| Spam on a near-free chain | Trust tiers + heuristics + Unknown fold |
| `lez-programs#144` may split the token program | Pinned; watch it |
| Distinct-account counting | Optional author |
| Market escrow or private buy | N1(f) gate |

## 11. Resume after a context clear

**Read, in order:**
1. memory `MEMORY.md`
2. `logos-kit/PROGRESS.md`
3. this plan (`logos-kit/docs/dev/PLAN-LP0001.md`)
4. `docs/dev/criteria-audit.md`
5. `docs/dev/pins.md`

**Start at stage A** (ask the user before merging and releasing), then D, W, T, …

**Gotchas:**
- PR #4 lives in the worktree `logos-kit-design` (`ui/wallet-v3`).
- Build lgx from the main checkout; in a worktree the 16 GB `target/` gets copied into the Nix store.
- Run QML harnesses with `QT_QPA_PLATFORM=offscreen`.
- Check `df` before docker or nix builds.
- The nix path is `/nix/var/nix/profiles/default/bin`.
- Firecrawl credits are nearly used up this cycle (about 150 left); use WebFetch or curl for reading.
- Research notes: `docs/design/research/token-ux-research.md` (MetaMask/Phantom/Rabby/Rainbow token UX, with citations).
