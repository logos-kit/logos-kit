# UX spec: tokens, NFTs, private proofs and the Market (stage D)

This extends [`ux-spec.md`](ux-spec.md). Its global rules (§0) apply here too: every async surface has its states, untrusted strings render as plain text, motion respects reduced-motion, and an unknown value shows "—", never 0.

- **Layout per screen:** [`lp0001-screens.md`](lp0001-screens.md) (the Refero lock: which real wallet screen each one copies, and what we change).
- **Design system:** Ledger, light and dark. Accents are ink; the only colour role is *warning* (unverified, risk). Plain rows, not cards.
- **Decisions and their reasons:** [`../dev/lp0001-decisions.md`](../dev/lp0001-decisions.md).
- **Formats:** the token list ([`token-list.md`](token-list.md)) and the metadata JSON ([`registry/schema/token-metadata.schema.json`](../../registry/schema/token-metadata.schema.json)).
- **Plan:** [`../dev/PLAN-LP0001.md`](../dev/PLAN-LP0001.md) §4 (product design) and §5 (references).

Every journey step names its CLI equivalent. A feature that exists in the app and not the CLI (or the reverse) is a bug.

---

## 0. Words on screen

People who have never used a crypto wallet must be able to read every screen. These are the only words we use, and what they mean.

| On screen | Means | Never say |
|---|---|---|
| **Token** | A coin anyone can create on LEZ. LGO is the network's own coin and is listed first. | "SPL", "fungible" |
| **Token ID** | The token's definition account. It is the token's identity: two tokens can share a name, never an ID. | "mint", "contract" |
| **Token account** | Where your balance of one token lives (your holding, usually your ATA). Shown only in token details. | "ATA", "holding" (UI only; docs may say holding) |
| **Collectible** / **NFT** | A one-of-a-kind item from a collection. "Collectible" in navigation, "NFT" in body copy. | "print", "NftPrintedCopy" |
| **Collection** | The NFT's definition: its name, art and how many can exist. | "definition" |
| **Master edition** | The original an NFT creator holds; it can print more copies. Only creators see this word. | — |
| **Private** | Only you can see the balance and history. Sending from it takes a few minutes because the wallet builds a proof. | "shielded", "zk" |
| **Vault** | One private place inside a private account. Each private NFT sits in its own vault so they can move separately. | "identity", "sub-account" |
| **Membership proof** | A message that says "the owner of this wallet holds an item from collection X" without saying which wallet or which item. | "zk proof", "attestation" (docs may use it) |
| **Verified** | On the Logos Kit token list. Not an endorsement. | "safe", "official" |
| **Added by you** | You added this token by its ID. | — |
| **Unknown** | Someone sent you this token and it isn't on the list. Hidden in a folded section; not counted in your total. | "spam" (for Unknown) |
| **Spam** | Hidden automatically because its name looks like a scam. | "scam" (we don't know that) |
| **Hidden** | You chose to hide it. | "deleted" (nothing is deleted) |
| **Pass** | The free Logos Kit Pass NFT. One per wallet. | — |

Amounts: `1.5 LGO`, `100 LKT`. A token with unknown decimals shows its raw whole number and the tag **"decimals unknown"**. Short IDs are first 4 + last 4 characters (`7Hk2…9Qpa`); full IDs are one tap away.

---

## 1. Journeys

Each step lists what the user does, what they see, the states that step can be in, and the CLI equivalent. Step IDs (C3, K2 …) are referenced from the stage exit checks and the QA scripts.

### 1.1 Collector: first run to buying an NFT privately

| # | The user… | They see | States | CLI |
|---|---|---|---|---|
| C1 | Installs Logos Kit from the Basecamp catalog and opens it | Cold start: the Logos Kit mark and "Starting the wallet…" while Basecamp loads its dependencies (16–40 s on first launch) | starting · slow (> 20 s: "Still starting. Basecamp is fetching what Logos Kit needs.") · failed (Retry + "Copy details") | `logos-kit --version` |
| C2 | Creates a wallet (password, 24 words, confirm) | `ux-spec.md` §1, then **Home on Public account 1** (not the empty private one) | as `ux-spec.md` §1 | `logos-kit init` |
| C3 | Taps **Get test funds** | Drip claim: "+1 LGO and 100 LKT on their way". LGO lands first; LKT appears in the token list on its own a few seconds later, with its logo and a check mark. That is the first-minute proof that detection works. | claiming · rate-limited (countdown) · outcome unknown (watching the balance) · funded · partly funded ("LGO arrived; LKT is still on its way") · drip down ("The test faucet isn't answering. Try again in a few minutes.") | `logos-kit faucet` (`--token` for LKT only) |
| C4 | Receives a token from a stranger | Nothing in the main list. The last row reads **"Hidden · Unknown (1) ›"**. A notification: "You received a token that isn't on the list." | — | `logos-kit token list --unknown` |
| C5 | Opens Unknown, looks, hides it or adds it | Unknown list (§2.2) → token detail with the warning panel → Hide, or **Add to my tokens** (with the impersonation check) | — | `token hide <id>` · `token add <id>` |
| C6 | Adds a token by ID (a friend's project) | Add-token tray (§2.4): paste → lookup skeleton → "Exact match" preview → decimals → Add → toast "LOGO added" → the row appears | invalid ID · not found · holding pasted · personal address pasted · not a token · already added · imitates a verified token (hard warning) · lookup failed (Retry) | `token add <id> [--decimals N]` |
| C7 | Sends a token | Send (§2.7) with the token picker, recipient checks, "Will create their token account", MAX that leaves the fee | `ux-spec.md` §3 plus §2.7 here | `send --token <id>` |
| C8 | Opens **Collectibles** and claims the **Pass** | Empty Collectibles: "No collectibles yet" + **Claim your free Logos Kit Pass** (opens the Faucet app). Claim lands the Pass in the public account; the Pass tile appears in "Logos Kit Pass (1)". | empty · claiming · already claimed ("This wallet already has its Pass") · supply exhausted · failed | `logos-kit faucet --pass` |
| C9 | Taps **Make private** on the Pass | Sheet: "Moving the Pass to Private account 1. Claiming was public; from now on only you can see where it is." → proving (§2.14 timing) → "In a private vault" | not enough LGO for the fee · proving · failed (nothing moved) · done | `nft make-private <collection>` |
| C10 | Opens the **Members' Wall** app and posts | The Wall connects with **proof only** (no account access). Tapping Post asks the wallet for a membership proof. | see §2.14 and §2.18 | `logos-kit prove --collection <id> --context <ctx>` |
| C11 | Approves the proof in the wallet | Proof request sheet: "They'll learn / They won't learn" with literal values → progress with ETA → "Proof ready, sent to Members' Wall" | see §2.14 | — |
| C12 | Sees the post on the Wall | Wall shows "Checked here first: valid · proves membership of Logos Kit Pass · hides your wallet and which item" → posts on-chain → "Posted in block N" | verifying · invalid (reason) · posting · posted · already used (`consumed`) | — |
| C13 | Lists an NFT on the Market | List sheet (§2.16): price in LGO, "Your public account is shown as the seller", "Listing ends any proofs made with this NFT" → approve → "Listed" | — | `market list <collection> --price 5` |
| C14 | Buys an NFT privately | Buy sheet: pay from Private account 1 → proving → "Bought. It's in a new private vault." | sold to someone else first (nothing charged) · price changed · proving · done | `market buy <listing> --from private` |

### 1.2 Creator: from art to a listed collection (Collection Studio app)

| # | The creator… | They see | States | CLI |
|---|---|---|---|---|
| K1 | Opens Collection Studio and connects (public account) | Connect sheet asks for "See this account" + "Propose transactions" | — | — |
| K2 | Picks the art file | File picker → preview drawn exactly as the wallet will draw it (same decoder, same square crop) | too large ("Pick an image under 5 MB") · unsupported type ("PNG, JPEG, WebP or GIF") · unreadable | `nft upload <file>` |
| K3 | Uploads to Logos Storage | Upload progress with bytes; result is a CID shown short with copy | storage node not running ("Start Logos Storage in Basecamp") · uploading · failed (Retry) · done | same |
| K4 | Fills name, description, supply, attributes | Form with byte counters; "Supply: how many can ever be printed" | name too long · supply 0 | `nft create-collection --name … --supply …` |
| K5 | Confirms "The art is permanent" | Hard confirm: "LEZ can't change a collection after it's created. Check the name and art now." | — | `--yes` required |
| K6 | Approves in the wallet | Approval sheet with the decoded effect "Create collection 'X' (1,000 items)" and the fee | — | — |
| K7 | Prints items (batch) | "Print 10 to…" (own account or a list of recipients) → progress per item | partial ("7 of 10 printed. Print the rest?") | `nft print <collection> --count 10 [--to …]` |
| K8 | Shares the collection ID | Copy ID + "Open in explorer" | — | `nft show <collection>` |
| K9 | Lists one on the Market | as C13 | — | as C13 |

### 1.3 Developer: gating an app with membership proofs

| # | The developer… | They see | Where |
|---|---|---|---|
| G1 | Starts from the template | `nix flake init -t github:logos-kit/logos-kit#dapp`; the template has an NFT gallery and a gating snippet | template README |
| G2 | Asks for proof-only access | `connect({ capabilities: ['request_proof'] })` → the wallet's connect sheet lists exactly that; `getSession()` returns `accounts: []` | `guides/token-gating` |
| G3 | Requests a proof | `requestMembershipProof({ collection, context })` → handle → `getProofStatus` → `getProofBundle` in ≤ 60 KB parts | `guides/token-gating` |
| G4 | Verifies off-chain | `verifyMembershipProof(bundle, { collection, context })` (npm wasm or the QML module) → `valid` or one reason from the shared list | `guides/verify-proof` |
| G5 | Gates on-chain | Submits the bundle; the gate program's attestation is the on-chain record; or calls `lez-gate` from their own program | `guides/gate-your-program` |
| G6 | Handles every outcome | declined (indistinguishable from "not a member"), `expired`, `stale`, `consumed`, `wrong_context`, `chain_unavailable`, `index_syncing` | the reason table in `concepts/membership-proofs` |

### 1.4 Judge: from the catalog to proof in about ten minutes of attention

| # | The judge… | They see |
|---|---|---|
| J1 | Reads the README hero and "For λPrize evaluators" | One sentence, the demo commands, CI badges, program IDs, a criteria → evidence page |
| J2 | Runs `e2e/demo.sh --testnet` | Numbered steps with explorer links: funded, public send, shield, private→private, token from private, testimonial |
| J3 | Runs `e2e/demo.sh --nft` | A headless SDK app requests a proof with only `request_proof`, shows the refusals, prints proving stats, verifies off-chain, submits on-chain, then shows `consumed` and the wrong-context / expired negatives |
| J4 | Installs from the catalog in Basecamp | The wallet, Members' Wall, Collection Studio, Market and Faucet in Applications; the wallet opens on the testnet |
| J5 | Walks C1–C12 by hand | As above; proving takes minutes and the screens say so up front |

---

## 2. Screens and their states

Layout, sizes and hierarchy are in [`lp0001-screens.md`](lp0001-screens.md). This section fixes content, states and copy.

### 2.1 Home: token list

**Order** (plan §4.1):
1. LGO, always first, never hidden.
2. Pinned tokens.
3. Verified and Added tokens with a balance, by balance (there are no prices on testnet), then by name.
4. A last row: **"Hidden · Unknown (N) ›"** when either count is above zero.
5. A text link under the list: **Manage tokens**.

**Row:** 36 px logo (bundled logo, or the initials circle) · name over symbol on the left · the amount right-aligned in tabular figures (it takes the column where Family shows dollar values) · a check mark after the name for Verified, an **"Added"** chip for Added by you · a lock glyph on the logo for balances held privately. Zero balances are hidden except LGO and pinned tokens.

**Total:** the header total counts LGO plus Verified and Added tokens only (no prices: shown as "LGO balance" on testnet; see decision D9).

| State | What shows |
|---|---|
| first load | 3 skeleton rows (opacity pulse; Canvas may not paint) |
| scanning (first sync or restore) | rows found so far + a thin progress line: "Finding your tokens… block 8,200 of 12,104" |
| loaded | rows |
| only LGO | LGO row + "Tokens you receive show up here." + **Add a token** |
| offline / stale | rows from cache + "As of block 12,104 · Retrying" under the total |
| a token's name can't be read | the row keeps the short Token ID as its name, with "Name unavailable" |
| an unknown token sits in your account's own token slot | nothing extra: it folds into Unknown like any other (decision D4) |

### 2.2 Unknown and Hidden

One screen with three tabs: **Unknown (N) · Spam (N) · Hidden (N)**.

- **Unknown** rows use the initials circle and the warning tone, never the token's own image: fetching it would tell the token's creator your IP address (decision D6).
- Each row opens token detail, which shows the trust panel (§2.5).
- Top copy: "Anyone can send you a token. These aren't on the Logos Kit list. They don't count in your total."
- **Spam** adds the reason: "Name contains a link", "Looks like LGO", "Hidden characters in the name", "Name is very long".
- Moving a token out of Unknown or Spam never makes it Verified. The toast says: "Showing this token doesn't mean it's safe."
- Empty: "Nothing here. Tokens you hide, and tokens that look like spam, appear here."

### 2.3 Manage tokens

- Search field: name, symbol or Token ID (paste works).
- Sections: Verified / Added by you / Unknown, each row with a visibility toggle and a pin control.
- Footer button: **Add a token**.
- Changes apply immediately; there's no Save.
- Searching for a Token ID that isn't in any list offers "Look up this Token ID" (goes to §2.4 prefilled).

### 2.4 Add a token by ID (tray)

1. **Paste or scan.** Field with Paste; Enter submits.
2. **Lookup** (skeleton row) reads the account and decodes it.
3. **Errors, each one plain:**
   - "That isn't a valid ID." (not base58 / wrong length)
   - "Nothing exists at this ID on LEZ testnet."
   - "This is a token account. Paste the token's ID instead." + **Use its token** (we read the definition from the holding)
   - "This is a personal address, not a token."
   - "This is an NFT collection. It will appear under Collectibles." + **Open collection**
   - "You already have this token." + **Open**
   - "Couldn't reach the network." + Retry
4. **Preview ("Exact match")**: name, kind, supply (raw if decimals unknown), Token ID short + copy, your balance, trust status.
5. **Decimals**: prefilled from the list or metadata; otherwise empty with "Not stored on chain. Ask the token's creator, or leave 0." (0–36).
6. **Warnings**:
   - always: "Anyone can create a token, including fake copies of real ones."
   - imitation (name or symbol confusable with a Verified token): hard warning in the warning colour: "This looks like **LKT** but isn't. The real LKT is `9xQe…P2aN`." Add needs an extra tick: "I understand this isn't LKT".
7. **Add** → toast "LOGO added" → the tray closes and the row is in the list (scrolled into view).

### 2.5 Token detail

- **Header:** logo, name + trust badge, big balance, two tiles: **Send** · **Receive**.
- **Activity** for this token only. Empty: "No activity with this token yet."
- **Details** (mono values, each with copy; IDs also open the explorer through the engine):
  - Token ID
  - Your token account (and "held privately" when it is)
  - Decimals and where they came from: "From the Logos Kit list" / "From the token's metadata" / "Set by you" / "Unknown"
  - Supply: current total; "The creator can mint more" (LEZ v0.3 lets the definition's key holder mint)
  - Metadata: standard, link, creators (only for Verified/Added; for Unknown: "Not loaded for unknown tokens")
- **Trust panel:**
  - Verified: "On the Logos Kit token list (v1.0.0). This isn't an endorsement."
  - Added by you: "You added this token on 6 Oct. It isn't on the Logos Kit list."
  - Unknown: "Unverified. Anyone can create a token with any name. Don't follow links in its name or metadata." + **Add to my tokens** · **Hide**
  - Spam: the reason + "Logos Kit hid this automatically." + **Show anyway**
- **⋯ menu:** Pin · Hide · Copy Token ID · Open in explorer.

### 2.6 Create a test token, and a squatted slot

**Create:** name (≤ 32 bytes, counter), supply (whole number; "Decimals aren't stored on chain. 1,000,000 with 6 decimals shows as 1.000000."), holder (public accounts with LGO for the fee), decimals (stored locally, offered to recipients via the metadata we write when the user opts in).
- Preflight: if the holder's own token slot is in use, the token goes to the holder's token account (ATA) instead, and the sheet says so.
- After: the new definition account is labelled "LOGO token ID" and hidden from the account switcher; the holder is selected; the token is pinned and marked "Created by you".

**A squatted slot** (an unknown token sitting in the account's own slot): shown and hidden like any unknown token. Its details explain: "Someone sent this token straight into this account's own token slot. Tokens sent with Logos Kit go to separate token accounts, so this doesn't block them." No "Clear slot" action: LEZ can't release a slot (decision D4).

### 2.7 Send: token additions to `ux-spec.md` §3

- **Token picker:** Verified and Added first, then "Unknown tokens" under a divider; search by name or Token ID.
- **Recipient checks** (in order, first match wins):
  1. A Token ID or a token account → error "That's a token's ID, not a person's address."
  2. A collection or NFT holding → error "That's an NFT, not an address."
  3. Lookalike of an address you've used (same first 4 and last 4, different middle) → warning row: "This looks like `7Hk2…9Qpa` you sent to before, but it's a different address." Send arms only after "I checked the address".
  4. First time sending to this address → note: "First time sending here."
  5. Their token account doesn't exist yet → note: "Will create their token account (included in the fee)."
- **Amount:** decimals enforced ("LKT has 2 decimals"); unknown decimals → whole numbers only with the "decimals unknown" tag. **MAX** leaves the fee when sending LGO: "Max leaves 0.0005 LGO for the fee."
- **Unknown token, first send:** one extra row in review, warning tone: "You're sending a token that isn't on the list."
- **Private code pasted:** the code's fingerprint shows under the field: "Code ends K7-QX". The receiver sees the same on their Receive screen.

### 2.8 Receive

- **Public:** QR, full address, Copy, and the line **"Accepts LGO, any LEZ token, and NFTs."**
- **Private:** the receive code, its fingerprint "Code ends K7-QX", Copy, and **"Accepts LGO and LEZ tokens privately. Each payment arrives in its own vault."**
- Never claim more than the wallet can find. A sender using a stock LEZ wallet sends into your account's own slot; the copy doesn't promise anything about third-party wallets.

### 2.9 Collectibles tab

- Grouped by collection, each group header: collection name, count, chevron. Expand → 2-column square tiles.
- Verified collections (the Pass, collections on the list) first; then Added; then **"Unknown collections (N) ›"** and **"Hidden (N) ›"** rows.
- Each tile: square media (or §2.13 placeholder), name, a lock glyph for private, a "Listed" tag for items on the Market.
- Empty: "No collectibles yet." + **Claim your free Logos Kit Pass**.
- Loading: tile skeletons; scanning: "Finding your collectibles… block N of M".

### 2.10 Collection page

Header: media, name, trust badge, "You hold N", floor price from the Market ("Floor 5 LGO" or "Not listed"). Then the holder's items as tiles. Details: Collection ID, items printed / can ever exist, creators, metadata link. ⋯ menu: Hide collection · Copy ID · Explorer.

### 2.11 NFT detail

- Square media (tap to view full size), name, collection row (tap → collection page).
- Rows: Collection · Item (its holding ID, with "This ID changes when the item moves" under an info dot) · Held in (Public account 1 / Private account 1, vault 3 / Listed) · Metadata (source and standard) · Creators · For a master edition: "Can print N more".
- **Action tiles:** Send · Make private (public only) · Prove (private only; public shows "Make private first to prove without revealing your wallet") · Sell (or **Cancel listing** when listed).

### 2.12 NFT send and make private

- **Review** states exactly one of: "Single item" or "**Entire master edition**: they'll be able to print N more." The second has the warning tone and a tick.
- Public → public: to the recipient's token account (created if needed).
- To a private code: lands in a fresh vault; review says "Arrives privately. Nobody else can see who received it."
- Private → private: "Nobody can link this send to you or to them."
- Sending ends any outstanding proofs made with this item: "Proofs you made with this item stop working."

### 2.13 Missing media

Never hide an NFT because its image failed. The tile keeps its square and shows:
- collection name + short item ID;
- a reason: **Web images off** (+ "Turn on in Settings") · **Unreachable** · **Invalid metadata** · **Too large** · **Unsupported type** · **Private: web images never load for private items**;
- **Refresh**.

### 2.14 Proof request and progress (wallet)

**Sheet** (distinct from transaction approvals: a shield kicker "Membership proof", no fee block):
- Requested by: the attested app identity (same block as connect).
- **They'll learn:** "Someone holds an item from **Logos Kit Pass**" · "The proof is for **members-wall:post**" · "It's valid until **14:32**".
- **They won't learn:** "Which wallet or account" · "Which item" · "Your balances or other holdings".
- Both lists draw their marks in ink, not green (`Permissions.qml` uses `Theme.ok` today; the proof sheet must not).
- **Using:** which private NFT (a picker if more than one in that collection). Anonymity line (only if the count is knowable; open question O2 in the decision log): "You're one of about 240 private holders." If fewer than 20: warning "Few people hold this privately, so this proof says less about you than usual, but more than you might expect."
- **Time:** "Takes about 5–8 minutes on this Mac." If a newer proof exists for this item: "+ about 6 minutes to refresh the item first, so older proofs stop working." Offer another item from the same collection when available.
- Buttons: **Prove** (arms after 500 ms) · **Decline**.

**Ineligible** (no private item in that collection, item held only publicly, item listed): the wallet shows the user why ("You don't have a private item from Logos Kit Pass." + **Make one private**) but the app gets exactly the same answer as a decline, and only after the user closes the sheet (decision D11).

**Progress:** the proving pill and timer from `ux-spec.md` §7; phases: Refreshing item → Building proof → Ready. On ready: "Proof ready. Members' Wall can use it once, until 14:32."

| State | Copy |
|---|---|
| low memory | "Proving needs about 4 GB of free memory. Close other apps, or use low-memory mode (slower)." |
| out of memory | "Proving ran out of memory. Nothing was sent. Try low-memory mode." |
| Basecamp restarted mid-proof | "The proof stopped when Basecamp closed. Start again?" |
| queued behind another proof | "Waiting for your other proof to finish (about 3 min)." |
| app stopped listening | "Members' Wall closed before the proof was ready. It's kept for 10 minutes if the app asks again." |

### 2.15 Connected apps

List of apps; each opens a page with one row per capability, written as what it lets the app do:
- "See Public account 1 and its balance"
- "Ask you to approve transactions"
- "Ask for membership proofs. Each proof still needs your approval."
- "See your NFTs in Public account 1" / "…in Private account 1"
- "Check whether you hold an item from a collection (yes or no)"

Each row: granted date, last used, **Revoke**. Footer: **Disconnect app** (revokes all). The proofs log: "Shared 3 proofs · last 6 Oct 14:02".

### 2.16 Market

- **Browse** (Market app): collections with floor price and listing count; a collection's listings; tap → item.
- **List** (wallet sheet): price in LGO; "Your public account `7Hk2…9Qpa` is shown as the seller." "Listing ends any proofs made with this item." Fee. → Listed.
- **Buy** (wallet sheet): price + fee; **Pay from** public or private; private: "The item arrives in a new private vault. Takes about 5–8 minutes." → proving → Bought.
- **Cancel listing**: "The item comes back to your account."
- States: sold before your purchase landed ("Someone bought it first. You weren't charged.") · listing cancelled by seller · price changed since you opened it · not enough LGO.

### 2.17 Pass claim (Faucet app)

- Card: Pass art, "Logos Kit Pass · free · one per wallet", "Claiming is public; proving later is private."
- **Claim** → "Pass on its way" → "Your Pass arrived" + **Make it private** (opens the wallet sheet C9).
- Already claimed / supply exhausted / drip down states as C8.

### 2.18 Members' Wall and Collection Studio (apps)

- **Wall:** posts with "Verified member of Logos Kit Pass" and an optional public author the user picks (approved separately, never the holding account). Before posting: the off-chain check result (valid · what it proves · what it hides). After: "Posted in block N" + explorer. A reused proof: "This proof was already used."
- **Studio:** K1–K9 above.

---

## 3. Wallet-wide

### 3.1 Account switcher with vaults

- Public accounts: name + short address + LGO balance.
- Private accounts: name + "Private" + LGO balance summed across vaults; expanded: "N vaults" with a one-line explainer ("Each private NFT or payment you receive gets its own vault. Balances add up here.").
- Token definition accounts never appear in the switcher (they are labelled under Settings → Accounts → "Token IDs you created").

### 3.2 Activity rows

| Event | Row |
|---|---|
| sent token | "Sent 10 LKT to `7Hk2…9Qpa`" |
| received token (Verified/Added) | "Received 10 LKT from `7Hk2…9Qpa`" |
| received Unknown token | "Received an unknown token" (no name, no amount in the main feed; detail on tap) |
| created token | "Created LOGO (1,000,000)" |
| NFT received / sent | "Received Logos Kit Pass" / "Sent Logos Kit Pass #… to …" |
| made private | "Moved Logos Kit Pass to Private account 1" |
| proof shared | "Shared a membership proof with Members' Wall" |
| listed / sold / bought / cancelled | "Listed … for 5 LGO" / "Sold … for 5 LGO" / "Bought … for 5 LGO" / "Cancelled listing" |
| app transaction | the app's display name, never its module ID |

History survives restarts (engine-persisted) and incoming rows come from the chain index.

### 3.3 Notifications (in-wallet toasts and the Basecamp badge)

Received a token · received an unknown token · received an NFT · proof ready · proof failed · your listing sold · a listing you were buying sold first.

### 3.4 Network and lock states

| State | What shows |
|---|---|
| offline | cached values + "As of block N · Retrying" |
| chain stalled (no new block for 2 min) | "The network hasn't produced a block for 3 minutes. Your transactions are waiting." |
| wallet locked with an app request open | the unlock screen says "Members' Wall is waiting for you." |
| intent timed out (the shell drops requests after 10 min) | the app gets `timeout`; the wallet shows "That request expired. The app can ask again." Proofs survive this through the handle (decision D12). |
| index syncing | "Finding your tokens and NFTs… block N of M". Proof verification answers `index_syncing`, never a false verdict. |

### 3.5 Widths, keyboard, motion

- 360 / 680 / 1024 px: tiles go 2 → 3 → 4 columns; sheets are full-width under 680.
- Keyboard: Tab order follows reading order; Enter confirms the primary action once armed; Esc closes a sheet unless busy; `/` focuses token search.
- Reduced motion: no tile scale, no count-up; skeletons still pulse in opacity (they carry meaning).

---

## 4. Error catalog additions

Plain copy shown to the user. Codes are the engine's; apps get protocol codes (`protocol/src/errors.ts`).

| Engine condition | Copy |
|---|---|
| recipient is a token ID / token account | That's a token's ID, not a person's address. |
| recipient is an NFT | That's an NFT, not an address. |
| decimals exceed the token's | LKT has 2 decimals. |
| recipient's own slot holds another token (legacy send) | They can't receive this token at that address yet. Logos Kit will send it to their token account instead. |
| not enough LGO for the fee | You need 0.0005 LGO more to cover the fee. |
| NFT listed | This item is listed on the Market. Cancel the listing first. |
| proof: no private item | You don't have a private item from {collection}. |
| proof: low memory | Proving needs about 4 GB of free memory. |
| proof: out of memory | Proving ran out of memory. Nothing was sent. |
| proof: stale (refreshed or moved) | This proof is out of date. Ask for a new one. |
| market: sold first | Someone bought it first. You weren't charged. |
| storage: node not running | Logos Storage isn't running. Start it in Basecamp. |
| media: too large | This image is over 5 MB. |

Verifier verdicts (`gate-verify`, the npm verifier and the QML module share them): `valid`, `malformed`, `bad_receipt`, `dev_receipt`, `wrong_program`, `wrong_collection`, `not_member`, `wrong_context`, `expired`, `consumed`, `stale`, `unknown_root`; and `chain_unavailable`, `index_syncing`, which are not verdicts. Each has one line of copy in `concepts/membership-proofs` (stage N8).

---

## 5. Trust tiers and spam rules (exact)

A token's tier is computed in the engine, in this order; the first match wins.

1. **Hidden by you**: the user hid this Token ID.
2. **Verified**: on the bundled Logos Kit token list for this network.
3. **Added by you**: the user added this Token ID.
4. **Spam**: any of
   - the name contains `http`, `www.`, `.com`, `.io`, `.xyz`, `.org`, `.net`, `t.me`, `@`, or `://`;
   - airdrop bait (case-insensitive word match): claim, airdrop, reward, free, gift, bonus, giveaway, congrats, visit, voucher;
   - its UTS-39 skeleton equals the skeleton of a Verified token's name or symbol (a lookalike), or it equals LGO / LOGOS;
   - it contains bidi controls, zero-width characters or other control characters;
   - the name is longer than 32 characters.
5. **Unknown**: everything else.

Rules:
- Unhiding or showing never raises the tier.
- Metadata (and images) load only for Verified and Added tokens.
- Totals count only LGO, Verified and Added.
- The same rules apply to NFT collections (the "Verified" list is the same file, with `kind: "collection"` entries).

---

## 6. CLI parity

| App | CLI |
|---|---|
| Home token list | `logos-kit token list` |
| Unknown / Spam / Hidden | `token list --unknown` · `--spam` · `--hidden` · `--all` |
| Add a token | `token add <id> [--decimals N] [--yes]` |
| Hide / show / pin | `token hide <id>` · `token unhide <id>` · `token pin <id>` · `token unpin <id>` |
| Token detail | `token info <id>` |
| Create a test token | `token create --name … --supply … [--decimals N] [--from <account>]` |
| Faucet (LGO + LKT, Pass) | `faucet` · `faucet --token` · `faucet --pass` |
| Collectibles | `nft list` · `nft collections` · `nft show <collection|item>` |
| NFT send / make private | `nft send <item> --to <addr|code>` · `nft make-private <item>` |
| Create / print | `nft upload <file>` · `nft create-collection …` · `nft print …` |
| Prove | `prove --collection <id> --context <ctx> [--out bundle.json]` |
| Verify | `verify-proof bundle.json --collection <id> --context <ctx>` |
| Connected apps | `apps list` · `apps revoke <app> [--capability …]` |
| Market | `market browse` · `market list` · `market buy` · `market cancel` |

Every command takes `--json`. Every command that changes state prints the same review lines the app shows and asks `Proceed? [y/N]` unless `--yes`.
