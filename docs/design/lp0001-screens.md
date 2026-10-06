# LP-0001 screens: the Refero lock

Per-screen Refero lock for stage D of [`docs/dev/PLAN-LP0001.md`](../dev/PLAN-LP0001.md) §5.

- This file fixes **layout**: what sits where, how big, what is primary, what is tappable.
- **Content, copy and states** live in [`ux-tokens-nfts.md`](ux-tokens-nfts.md) §2. Where the two overlap, that file wins on words and this one wins on layout.
- Every reference screen is saved locally in `refs/lp0001/` as the original JPG from Refero. The folder is not committed (they are Refero's screenshots); fetch any of them again with `refero_get_screen_image` and the ID in the table.
- Sizes were measured on 375 pt wide iOS screenshots (1125 px at 3x). Read "pt" as QML px at 1x. They are ±2 pt.
- Anything not visible in a reference is marked **(inferred)**.

## The 15 screens

| # | Screen | Primary reference | Image file(s) |
|---|---|---|---|
| 1 | Home token list | Family `d6a80a98` | `01-family-home-tokens.jpg`, `01-familyweb-hidden-row.jpg` |
| 2 | Manage tokens | Phantom `d9fedd43` | `02-phantom-manage-tokens.jpg`, `02-family-edit-tokens.jpg` |
| 3 | Add token by ID | Family `3b483d4a` → `123cc956` | `03-family-add-lookup.jpg`, `03-family-add-match.jpg`, `03-phantom-watch-address.jpg` |
| 4 | Unverified token | Glow `62104eae` | `04-glow-unverified-token.jpg`, `04-uglycash-warning-pill.jpg`, `04-uglycash-issues-sheet.jpg` |
| 5 | Token detail | Glow `92348324` | `05-glow-token-detail.jpg`, `05-family-token-detail.jpg` |
| 6 | Receive | Coinbase `724cf794` | `06-coinbase-receive.jpg`, `06-family-receive.jpg` |
| 7 | Empty / loading | Family `53520250` | `07-family-empty-tokens.jpg`, `07-fuse-empty-wallet.jpg`, `07-phantom-loading-skeleton.jpg` |
| 8 | Collectibles tab | Family `53dc227a` | `08-family-collectibles.jpg` |
| 9 | Collection page | Glow `b2496e7b` (light) | `09-glow-collection-light.jpg`, `09-glow-collection-dark.jpg` |
| 10 | NFT detail | Glow `37f23934` | `10-glow-nft-detail.jpg`, `10-glow-nft-detail-menu.jpg` |
| 11 | NFT send review | Family `358cccaa` | `11-family-send-review.jpg`, `11-glow-nft-receipt.jpg` |
| 12 | Missing media | Rarible `216dd664` | `12-rarible-missing-media.jpg` |
| 13 | Proof request sheet | Glow `ca153aec` | `13-glow-connect-sheet.jpg` |
| 14 | Connected apps | Glow `8ea91cb8` | `14-glow-connected-sites.jpg`, `14-health-access.jpg` |
| 15 | Market | Coinbase `be0166cf` | `15-coinbase-nft-listing.jpg`, `15-family-nft-floor.jpg`, `15-glow-nft-activity.jpg` |

## Rules for every screen

These replace the reference's styling everywhere below. Each screen's "What we change" only lists what is specific to it.

- **Accent → ink.** Their blue, purple, magenta and green buttons, toggles, checks and links become `Theme.action` (near-black in light, white in dark) with `Theme.actionText` on top.
- **One colour role: warning.** `Theme.warn` (`#a86a00` light, `#ffd60a` dark) is used only for Unverified, Unknown, spam and risk. Their orange, amber and yellow map to it. Their green "+amount", green checks and red "Remove" do **not** get a colour: they become `Theme.text` or ink.
- **Plain rows, not cards.** Where a reference wraps rows in cards (Phantom, Glow), we draw rows on the page background. Separation is spacing, or a `Theme.line` hairline where the reference uses one.
- **No fiat on testnet.** Every "$" value, % change, price chart and market-cap stat is dropped. Amounts are in the token's own unit.
- **LGO is the native token.** It is always the first row, uses the Logos mark on a black disc (`TokenIcon` native), and can't be hidden.
- **IDs and addresses** use `Theme.mono` and the short form `7Hk2…9Qpa` (Glow does the same with its mint addresses).
- **Untrusted strings** (token names, NFT names, descriptions, app names) render as `Text.PlainText` with an elide and a length cap.
- **Skeletons pulse in opacity** (Canvas may not paint). No shimmer gradient that depends on Canvas.
- **Radii** come from the theme: sheets `rSheet` 32, grouped surfaces `rCard` 24, rows and fields `rRow` 18. Media tiles use 12 (inferred; the references sit between 8 and 14).

---

## 1. Home token list

**References**
- Family, iOS home, `d6a80a98-afc5-4335-bf7f-2c78958264cb`, https://refero.design/screens/d6a80a98-afc5-4335-bf7f-2c78958264cb (primary).
- Family, web wallets page, `f2b7a39b-a97e-44b4-b8c0-6f9ecdea6d19`, https://refero.design/pages/f2b7a39b-a97e-44b4-b8c0-6f9ecdea6d19 (the "hidden" row at the list end).

**Anatomy (Family iOS), top to bottom**
1. **Header row.** Left: wallet avatar, 36 pt circle on a light grey disc. Then the wallet name, bold, about 26 pt. Right: scan glyph, 24 pt, grey.
2. **Notice bar.** Full content width, 39 pt tall, radius about 12, filled light grey. Centred eye glyph and grey 15 pt text. Not tappable.
3. **Tab row.** Left: "Tokens" (active, black, 17 pt semibold) and "Collectibles" (inactive, grey, same size). Text tabs, no pill, no underline. Right: the total, bold about 22 pt, then a ⋮ overflow (grey).
4. **Hairline** under the tab row, content width (24 pt side margins).
5. **Token rows.** No separators between rows. Row pitch 62 pt.
   - Logo: 44 pt circle at the 24 pt margin, 13 pt gap to the text.
   - Left column: name (primary, 17 pt semibold, elided at the right column) over amount + symbol (secondary, 15 pt grey).
   - Right column, right-aligned: value (primary, 17 pt) over % change (secondary, 15 pt grey; green only when positive).
   - The whole row is tappable.
6. **Initials fallback** (logo-less tokens: "W", "F", "SFP", "C"). A filled circle at logo size with 1–3 white bold initials, about 13 pt, centred. Each token gets a different flat colour.
7. **Bottom tab bar**, three glyphs (not ours: Basecamp has its own chrome).

**Anatomy (Family web), the hidden row**
- The wallet list is a grouped block of rows with hairlines between them. Each row: avatar, name over short address, amount on the right, then a ⋯ button.
- The **last row** is text only: "View 1 Hidden Wallet", regular weight, starting at the avatar's left edge, with a chevron › at the right edge. Same height as the rows above. Tapping it opens the hidden list.
- After hiding, a small dark pill toast sits bottom-centre: a check glyph and "Wallet Hidden".

**Copy worth keeping**
- "View 1 Hidden Wallet" (count inside the label).
- "Wallet Hidden" (two-word toast).

**States visible:** loaded only. Watch-only notice bar. Hidden-count row. Hide toast.

**What we take**
- The row anatomy: logo, name over secondary line, numbers right-aligned, no separators, about 62 pt pitch.
- Text tabs "Tokens · Collectibles" on one line with the total at the right end of the same line, and a hairline under it.
- The initials fallback: a circle the size of the logo with 1–3 initials.
- The hidden row as the last row of the list: plain text with the count, a chevron, no icon.
- The quiet full-width notice bar, used for the offline/stale and scanning lines.

**What we change for Logos Kit**
- Logo 36 pt and row 68 pt (existing `TokenRow`, `TokenIcon size: 36`) at our 360–1024 widths.
- Right column: the **amount** in tabular figures (primary). There is no fiat value and no % change. Left secondary line: the symbol, plus "Private" when held privately (e.g. `LGO · Private`). This keeps the numbers on the right edge, where Family puts them.
- Trust marks sit after the name: a small ink check for Verified, an "Added" `Tag` for Added by you.
- The initials circle is **monochrome**: one of a few ink/grey tones derived from the Token ID, with initials in the contrasting colour. Unknown tokens use the warning tone and never their own image (ux-tokens-nfts §2.2).
- The total reads as the LGO balance (no prices on testnet).
- The last row reads "Hidden · Unknown (N) ›". Under the list sits a "Manage tokens" text link (inferred placement: centred, 15 pt, `text2`).

---

## 2. Manage tokens

**References**
- Phantom, "Manage token list", `d9fedd43-8ab2-4498-81c5-b8e4c361350e`, https://refero.design/screens/d9fedd43-8ab2-4498-81c5-b8e4c361350e (primary).
- Family, token edit mode, `43c2d253-a956-422d-b47c-3da35a741aa1`, https://refero.design/screens/43c2d253-a956-422d-b47c-3da35a741aa1 (pin and muted hidden rows).

**Anatomy (Phantom), top to bottom**
1. **Sheet header.** ✕ at the left (24 pt glyph), title "Manage token list" centred, 17 pt semibold. No right action.
2. **Search field.** Full width, 47 pt tall, radius about 8, 1 px outline, magnifier glyph left, placeholder "Search…" grey.
3. **Token rows** (cards in Phantom). Card height 74 pt, 8 pt gaps.
   - Logo 48 pt circle; a duplicate token carries a small square badge on the logo's bottom-right corner.
   - Name (primary, 17 pt semibold) over "0 SOL" (secondary, 15 pt grey).
   - Toggle at the right edge, 51 × 31 pt, on = accent track.
   - The toggle is the only control. Changes apply at once; there is no Save.

**Anatomy (Family edit mode)**
1. The header fades to about 20% opacity while editing.
2. **Control row.** Left: a sort glyph ⇅ and "Highest Value" (17 pt, black). Right: "Done" (accent, 17 pt semibold). Hairline below.
3. **Rows**, same as home, plus a 22 pt selection circle at the far right. The value column shifts left to make room.
4. **Hidden rows** are the same row at about 35% opacity, with an eye-slash glyph (14 pt, grey) right after the name.
5. **Pinned (starred) rows** carry a 16 pt star badge on the logo's top-left corner.
6. **Selected rows** get a pale tinted background, radius about 12, inset 14 pt from the screen edges.
7. **Floating action bar**, bottom-centre over the list: a white rounded container with a soft shadow, holding two 85 × 60 pt buttons, glyph over label: "Unhide" (eye) and "Star" (star).

**Copy worth keeping**
- "Manage token list" (title).
- "Search…" (placeholder).
- "Unhide" / "Star" (batch actions).

**States visible:** all toggles on (Phantom). Mixed selection with hidden rows (Family). The Phantom flows include "Searching for tokens without results" (not opened here).

**What we take**
- Phantom's structure: sheet, ✕ left, centred title, search on top, one row per token, a toggle at the right, changes apply at once.
- Family's hidden-row treatment: the row stays in place, dimmed, with an eye-slash after the name.
- Family's pin marker as a small badge on the logo corner.
- The corner-badge slot on the logo (Phantom's bottom-right badge) is where our "private" lock glyph goes.

**What we change for Logos Kit**
- Rows sit on the page background with no cards. Row height 68 pt, logo 36 pt.
- Toggle "on" is ink (`Toggle` uses `Theme.action`).
- Each row gets a **pin control** just left of the toggle: a 32 pt icon button with a pin glyph, filled ink when pinned (inferred: Family uses batch "Star"; we need it per row). The pinned state also shows Family's corner badge on the logo, in ink.
- Rows are grouped under small section labels: "Verified", "Added by you", "Unknown" (15 pt, `text2`, 24 pt above each). Unknown rows use the warning-tone initials circle.
- Hidden rows: off toggle + Family's dimming (opacity 0.4) + eye-slash after the name.
- The search field is a filled `rRow` field (`Theme.surface2`, no outline), matching screen 3.
- No batch selection mode and no floating bar (inferred: per-row controls cover it). A footer button "Add a token" spans the content width.
- LGO is listed first with its toggle locked on and disabled.

---

## 3. Add token by ID (tray)

**References**
- Family, Add Address, looking up, `3b483d4a-3131-4787-8bcb-f8963d7c51cd`, https://refero.design/screens/3b483d4a-3131-4787-8bcb-f8963d7c51cd (primary, step 1).
- Family, Add Address, exact match, `123cc956-8977-4830-9981-e733f88815d1`, https://refero.design/screens/123cc956-8977-4830-9981-e733f88815d1 (primary, step 2).
- Phantom, Watch Address, `72367c14-65b6-40ef-99cf-e92407337472`, https://refero.design/screens/72367c14-65b6-40ef-99cf-e92407337472 (explainer and field stack).

**Anatomy (Family tray), top to bottom**
1. **Floating sheet.** Inset 17 pt from the screen sides and lifted above the bottom edge. Corner radius about 36 on all four corners. The page behind is dimmed grey.
2. **Header.** Title "Add Address" left, bold 22 pt, 31 pt inner padding. Right: ✕ in a 32 pt light-grey circle. Hairline under the header, inset to the padding.
3. **Lookup field.** Full inner width, 48 pt tall, radius about 13, filled light grey, no border.
   - Leading: magnifier glyph, grey.
   - Value: the pasted ID in bold, one line, elided at the right with "…".
   - Trailing slot: a small accent **spinner** while looking up, then a grey **ⓧ clear** button once done.
4. **Looking up (state 1).** Two skeleton rows under the field. Each: a 44 pt grey circle, then two grey bars (about 100 × 16 and 115 × 16 pt, fully rounded). Row pitch 64 pt.
5. **Exact match (state 2).**
   - A section label "Exact Match", 15 pt grey, left.
   - One result row: a 44 pt grey circle with a wallet glyph, the short address bold (primary) over "0 ETH" grey (secondary), and a filled accent check circle at the right (selected).
6. **Primary button.** Full inner width pill, 48 pt tall, at the bottom of the sheet. "Add" in white bold. Disabled while looking up: the same pill at about 35% strength.

**Anatomy (Phantom Watch Address)**
1. Header: ← left, title centred.
2. A 97 pt circle with an eye glyph, centred.
3. Explainer: 4 centred lines, 17 pt grey.
4. Three stacked filled fields (56 pt tall, radius about 14, 16 pt gaps): "Network | Ethereum ›" (a picker row), a name field with ⓧ, and the address as a multi-line field that wraps.
5. "Import" full-width pill at the bottom.

**Copy worth keeping**
- "Exact Match" (result label).
- "Add" (one-word primary).
- "You'll have view-only access and won't be able to sign" (Phantom's plain consequence line; pattern only).

**States visible:** looking up (spinner + skeletons, button disabled). Match found (check, button enabled). Phantom: filled form.

**What we take**
- One tray with one field: paste → spinner in the field → skeleton rows → a single "Exact match" preview row → one primary button.
- The trailing slot in the field changes with state (spinner, then clear).
- The disabled primary stays visible at reduced strength rather than disappearing.
- Phantom's centred plain-language explainer above the fields (our "Anyone can create a token…" line goes there).

**What we change for Logos Kit**
- Our `Sheet` is bottom-attached with `rSheet` 32 top corners (inferred: the floating inset sheet is an iOS look; at 680/1024 px we centre the same sheet as a dialog).
- The trailing slot has three states: **Paste** (an ink text button, when empty) → spinner (looking up) → ⓧ clear (done). Enter submits. **Scan** shows only if a camera is available (inferred; Basecamp desktop usually has none).
- The preview row is a token row: 36 pt logo or initials, name + trust status over "Supply 1,000,000 · `7Hk2…9Qpa`", and the user's balance on the right. Below it, `InfoRow`s for decimals and the trust line (ux-tokens-nfts §2.4).
- No selection check: there is only one match, so the button is enough. Errors replace the preview row with one plain line plus its action button (§2.4 list).
- The imitation warning is a `Notice` in the warning tone above the button, with the "I understand this isn't LKT" `CheckRow`. The button stays disabled until it is ticked.
- Button "Add" is ink.

---

## 4. Unverified token warning

**References**
- Glow, unverified coin, `62104eae-c20e-4d7c-9618-aea5817e2084`, https://refero.design/screens/62104eae-c20e-4d7c-9618-aea5817e2084 (primary: status as plain text in the header and a row).
- UGLYCASH, token stats with warning pill, `220a366b-3ddf-4d79-a40c-d46c8c1f1a2f`, https://refero.design/screens/220a366b-3ddf-4d79-a40c-d46c8c1f1a2f.
- UGLYCASH, issues sheet, `2d23b8bd-08a6-4c1b-ade1-2e3ddcd31f73`, https://refero.design/screens/2d23b8bd-08a6-4c1b-ade1-2e3ddcd31f73.

**Anatomy (Glow)**
1. Sheet with a handle. Top-left: the token's image, 36 pt, uncropped. Top-right: ☆ in a 32 pt grey circle.
2. **Name** bold 22 pt. Directly under it, **"Unverified"** at the same size, regular, grey. It takes the place where a balance would go.
3. Full-bleed hairline.
4. **"About"**, section header, 17 pt bold. Three label/value rows, 32 pt pitch, no separators: label grey left, value right.
   - "Total Supply · 1,000,000"
   - "Mint Address · 13zQL…ZCQsS" (monospace)
   - "Verification Status · **Unverified**", the value in amber. It is the only coloured text on the screen.
5. Hairline. **"Recent Activity"** header. Empty state centred: a 56 pt grey circle with a bolt glyph, "No Activity" (20 pt bold), "You have never transacted in this coin." (15 pt grey).
6. There is no price chart for this unverified coin.

**Anatomy (UGLYCASH pill and sheet)**
1. Stats list: label grey left, value right, **dotted** hairlines between rows, 49 pt pitch. "Contract Address" has a small copy glyph after the label.
2. **Warning pill** just above the primary button: full width, 39 pt, fully rounded, pale warning fill. Left: ⚠ glyph. Centre: "This token has 1 issues", semibold, warning colour. Right: ⓘ. The whole pill is tappable.
3. Primary "Buy" button below it, a 56 pt pill.
4. **Issues sheet** (tap the pill): handle; a large warning illustration; heading bold 28 pt, **left-aligned**; one grey support sentence; then one risk row: a 23 pt shield-slash glyph, "Unverified Token" (16 pt semibold) over a 2-line grey explanation (13 pt). "Got it" is a full-width black pill.

**Copy worth keeping**
- "Unverified" (one word, no exclamation).
- "Verification Status" (row label).
- "Please be cautious and do your own research." (UGLYCASH sheet).
- "Got it" (dismiss).

**States visible:** unverified with no activity (Glow). Warning pill → issues sheet (UGLYCASH).

**What we take**
- Glow's restraint: the status is a word, not a banner. It appears twice: under the name, and as a detail row whose value alone is in the warning colour.
- UGLYCASH's pill placement: one warning line directly above the primary action, tappable for the reasons.
- The issues sheet's left-aligned heading + one row per reason (glyph, bold title, quiet explanation) + one dismiss button.

**What we change for Logos Kit**
- "Unverified" under the name uses `Theme.warn` (Glow uses grey there). The detail row "Trust · Unverified" uses `Theme.warn` for the value.
- The pill becomes a `Notice` with tone `warn` on the plain background: no pale fill (inferred: one colour role, so the tint is the text and glyph only). It sits above the token detail's Send/Receive tiles and above any review "Confirm".
- The issues sheet has no illustration. A 20 pt ⚠ glyph in `warn` sits before the heading. One row per reason, using the ux-tokens-nfts §5 reasons. Buttons: **Hide** (ink) and **Keep showing** (secondary) (inferred: "Got it" alone gives the user no way out).
- Unknown tokens never load their own image: the 36 pt initials circle in the warning tone replaces Glow's top-left image.
- Rows have no dotted dividers. Plain rows with spacing, as in Glow.

---

## 5. Token detail

**References**
- Glow, token detail, `92348324-9b7f-4aa6-8c04-afa9fb532efa`, https://refero.design/screens/92348324-9b7f-4aa6-8c04-afa9fb532efa (primary).
- Family, token detail, `68bc2123-0d62-45c9-9537-e617f80c3ba4`, https://refero.design/screens/68bc2123-0d62-45c9-9537-e617f80c3ba4 (header and "Owned by").

**Anatomy (Glow), top to bottom**
1. Sheet with a handle. **Title bar:** the token name centred, 17 pt semibold. Right: ★ in a 32 pt grey circle (favourite).
2. Price chart and a range selector "1H 1D 1W 1M 3M" (the active one in a grey circle). We drop both.
3. Hairline. **Balance | Value** on one line: left block "Balance" (15 pt grey) over "240,615 SDO" (20 pt semibold); right block right-aligned "Value" over "$0.18585".
4. Hairline. "Market Stats": a 3-column grid of label over value. We drop it.
5. Hairline. **"About"**: "Total Supply" and "Mint Address" rows, label grey left, value right. Under them, a row of three fully rounded grey chips with a glyph + label: "Twitter", "Discord", "Website" (31 pt tall).
6. Hairline. **"Recent Activity"**: rows with a 20 pt direction glyph, "Received from EX73…" (primary) over "Success · Jan 17" (secondary), and on the right "+240.6k SDO" (green) over "$0.19" (grey). Row pitch about 58 pt.

**Anatomy (Family)**
1. A handle. Top-left: the token logo or initials circle, **56 pt**. Top-right: ☆ and ⋯ (grey glyphs, no circles).
2. **Name** bold 28 pt, wrapping to 2 lines when long.
3. Price and % (dropped). Chart and range (dropped).
4. Hairline. **Balance | Value**: two centred columns split by a vertical hairline. "Balance" (grey) over a 20 pt token icon + amount (24 pt semibold).
5. **"Owned by"** pill: full width, 44 pt, radius about 16, light grey fill, centred text "Owned by" (grey) + a small wallet glyph + "Binance 14" (bold).
6. "Links" section with a link glyph, then a "Contract Address" chip.

**Copy worth keeping**
- "Balance" (label over the big number).
- "About" / "Recent Activity" (section headers).
- "Owned by" (account attribution).

**States visible:** loaded with one activity row (Glow). Loaded, no activity shown in view (Family).

**What we take**
- Family's header: big logo top-left, actions top-right, the name large and left-aligned and allowed to wrap.
- Glow's section rhythm: hairline, bold section header, label/value rows, then activity at the end.
- The "Owned by" line: our "Your token account" lives there, as one full-width row.
- Glow's activity row anatomy: glyph, what happened over status · date, amount on the right.

**What we change for Logos Kit**
- Header: 56 pt logo, ⋯ at the top right (Pin · Hide · Copy Token ID · Open in explorer). No star.
- Name 28 pt bold with the trust mark after it. The big number under it is the **balance** (32 pt tabular) + symbol; there is no price line.
- Under the balance: two `ActionTile`s, **Send** (ink) and **Receive** (inferred: Glow and Family put Send/Receive elsewhere; our spec needs them here).
- The trust panel (screen 4) sits between the tiles and Activity, as a `Notice` row. It is neutral for Verified and Added, `warn` for Unknown.
- No chart, no market stats, no fiat column.
- "Details" replaces "About". `InfoRow`s with mono values and a copy glyph: Token ID · Your token account · Decimals (+ source) · Supply. IDs also get an explorer glyph.
- Glow's link chips are kept only for Verified tokens with list metadata, drawn as outlined `rRow` chips in `text`. They open through the engine.
- Activity amounts are `Theme.text`, with "+" and "−" signs. No green.
- Activity sits **above** Details (spec order). Empty: Glow's centred empty block with "No activity with this token yet."

---

## 6. Receive

**References**
- Coinbase, receive, `724cf794-7deb-47ad-877a-869baf66e7bc`, https://refero.design/screens/724cf794-7deb-47ad-877a-869baf66e7bc (primary: the "what this address accepts" line).
- Family, receive (dark), `bedf856e-f10b-4291-9393-62389284c912`, https://refero.design/screens/bedf856e-f10b-4291-9393-62389284c912.

**Anatomy (Coinbase), top to bottom**
1. ✕ top-left, no title.
2. QR, about 206 pt square, centred, black on white, no frame.
3. Hairline at the 24 pt side margins.
4. **Address block.** "Address" (17 pt) over the **full** address, about 20 pt regular, wrapping over 3 lines in about 60% of the width. To its right, vertically centred: the copy button, a fully rounded pill (90 × 42 pt) that reads "Copied" after a tap.
5. **Accepts line.** An ⓘ glyph (16 pt, grey) + "This wallet only accepts ERC-20 tokens on…" (15 pt grey, 2 lines) + an inline "Learn more" link.
6. Bottom: "Share address", a full-width pill, 56 pt.

**Anatomy (Family)**
1. Title "Receive" left, bold 28 pt. ✕ right.
2. Account name centred, bold 22 pt. Under it, the short address (grey) + a copy glyph. This line is tappable.
3. QR in a white rounded card (about 310 pt, radius 24), with dot modules and a logo in the centre.
4. Under the QR: 3–4 centred grey lines (13 pt) on what the address accepts and what is lost otherwise.
5. Bottom: a centred, content-width pill "Share Address" (about 196 × 47 pt), dark grey.

**Copy worth keeping**
- "This wallet only accepts …" (shape of the accepts line).
- "Sending other assets may result in permanent loss." (Family; tone only, see below).
- "Copied" (the copy button's done state).

**States visible:** copied (Coinbase). Default (Family).

**What we take**
- Coinbase's layout: QR → hairline → the **full** address as text, wrapped, with a copy pill beside it → the accepts line with an ⓘ → one bottom action.
- The copy button morphs into "Copied" in place (`AddressChip` already morphs to a check).
- Family's identity line over the QR: account name + short address, centred.

**What we change for Logos Kit**
- Header: "Receive" left (Family), ✕ right. Under it, a `SegmentedControl` **Public | Private** (inferred: neither reference has two address kinds).
- Public: QR (`QrCard`, plain modules, no centre logo) → full address in `Theme.mono` wrapped → **Copy** pill in ink, "Copied ✓" after the tap → the accepts line: "Accepts LGO, any LEZ token, and NFTs."
- Private: the receive code in mono + "Code ends K7-QX" + Copy + its accepts line (ux-tokens-nfts §2.8).
- The accepts line uses `text2` with an ⓘ glyph, no link. We don't use Family's "permanent loss" warning: LEZ has nothing to warn about here, and the warning colour is kept for real risk.
- "Share address" is dropped (Basecamp has no share sheet). Copy is the primary action.
- The "Copied" green becomes ink.

---

## 7. Empty and loading states

**References**
- Family, empty tokens, `53520250-243a-4747-a685-7b7be0698126`, https://refero.design/screens/53520250-243a-4747-a685-7b7be0698126 (primary: empty).
- Fuse, empty wallet, `b8915d3d-cad9-49d4-b47f-2b8f4bb6a6c4`, https://refero.design/screens/b8915d3d-cad9-49d4-b47f-2b8f4bb6a6c4 (compact ink "Receive").
- Phantom, loading skeleton, `652341ab-1b79-4870-9d8e-3092ed2c2be0`, https://refero.design/screens/652341ab-1b79-4870-9d8e-3092ed2c2be0 (primary: loading).

**Anatomy (Family empty)**
1. Header and tab row as on screen 1. The total reads "$0.00".
2. The **native token row is real**: Ethereum logo, "0 ETH", "$0.00". It is shown even at zero.
3. Under it, 2–3 **ghost rows**: a 44 pt pale circle + two pale bars on the left, one short bar on the right. Each is paler than the one above, fading to nothing. They are decoration, not loading.
4. Over the fade, centred: "There's nothing here, yet" (20 pt semibold) and 2 grey lines (17 pt).
5. "Receive": a wide grey pill (about 295 × 48 pt), black label.
6. "Learn more about tokens ⓘ" (13 pt grey).
7. A toast at the top: "Copied address!" on a white pill with a shadow.

**Anatomy (Fuse empty)**
- Centred: "There is nothing here yet" (17 pt semibold), 2 grey lines, then a compact **black** pill "Receive" with a ↓-in-circle glyph (about 98 × 37 pt).
- A "Copied" toast with a ✓ at the top.

**Anatomy (Phantom loading)**
1. Header is real (avatar, account name, scan, search).
2. Balance skeleton: two centred bars (about 180 × 10 and 100 × 10 pt), stacked.
3. Three skeleton rows (cards): a 48 pt circle, two bars on the left (long over short), two bars on the right (short over long). Row 74 pt.

**Copy worth keeping**
- "There's nothing here, yet" (Family).
- "Deposit tokens to your address …" (shape: say what to do next).
- "Receive" (the only button).

**States visible:** empty with the native row (Family). Empty with promos (Fuse). First load (Phantom).

**What we take**
- Empty home keeps the **LGO row** real, then shows ghost rows fading out under a centred message and one action. The list never looks broken.
- Loading uses skeleton rows with the same geometry as real rows (circle + two bars left, bars right), so nothing jumps.
- Fuse's compact ink pill for the single empty-state action.
- The balance skeleton is centred bars where the number will be.

**What we change for Logos Kit**
- Ghost rows are `TokenRow { loading: true }` at stepped opacity (0.5, 0.3, 0.15), not pulsing. Real skeletons pulse in opacity (0.4 ↔ 1.0, about 1 s).
- Empty copy (ux-tokens-nfts §2.1, "only LGO"): "Tokens you receive show up here." Action: **Add a token**, a Fuse-size ink pill. "Receive" is a secondary text button under it (inferred: the balance header already has Receive).
- Skeleton rows have no cards: 3 rows on the page background (`EmptyState` / `Skeleton`).
- The scanning state adds a thin progress line under the tab row with "Finding your tokens… block N of M" in `text2` (inferred position: where Family's hairline is).
- No promo cards, no FAB, no "Learn more" link.
- Toasts use our `ToastHost` (bottom, dark pill), as on screen 1. Not the top.

---

## 8. Collectibles tab

**Reference**
- Family, Collectibles, `53dc227a-ad14-4dd5-87cd-b8ab9adf6da6`, https://refero.design/screens/53dc227a-ad14-4dd5-87cd-b8ab9adf6da6.

**Anatomy, top to bottom**
1. Header and notice bar as on screen 1.
2. Tab row: "Tokens" (grey) · "Collectibles" (black, active). **No total** on this tab; only the ⋮ at the right. Hairline below.
3. **Collection header rows**, one per collection. Row pitch 52 pt.
   - Collection logo, 32 pt circle. A collection without a logo shows a pale grey circle with a stacked-cards glyph.
   - Name, 17 pt semibold, one line, elided.
   - Right: the count (17 pt semibold) and a chevron (14 pt grey): **›** when collapsed, **⌄** when expanded.
   - The whole row toggles the group.
4. **Expanded group.** Square tiles in **2 columns** under the header, starting at the left margin. Tile about 148 pt, gap about 26 pt between columns, radius about 10. A lone item sits in the left column with the right one empty. The next header starts about 42 pt below the tiles.
5. Tiles show only the media. No caption under the tile.

**Copy worth keeping:** none beyond the tab names.

**States visible:** mixed: one collapsed group (count 1, ›), two expanded (1 and 2 items). Missing collection logo (PAXOS row).

**What we take**
- Grouping by collection with a header row: logo, name, count, chevron that flips between › and ⌄.
- 2-column square tiles under an expanded header.
- The grey stacked-cards circle as the fallback collection logo.
- No total on the Collectibles tab.

**What we change for Logos Kit**
- Header row 52 pt, logo 32 pt; the trust mark sits after the name (as on screen 1).
- Tiles get a **caption under the media** (inferred: Family has none, but our tiles carry state): the item name (15 pt, one line), plus a lock glyph for private and a "Listed" `Tag`. Gap 12 pt (inferred: Family's 26 pt is wide at 360 px).
- No glow or shadow on tiles. Tiles are flat with radius 12. A missing image shows the screen 12 placeholder inside the same square.
- Verified collections first, then Added. Then two text rows in the screen 1 style: "Unknown collections (N) ›" and "Hidden (N) ›".
- Groups start expanded when the wallet holds 4 or fewer items in total (inferred). Otherwise collapsed. The state is remembered per collection.
- Empty: screen 7's layout with "No collectibles yet." + **Claim your free Logos Kit Pass**.
- Loading: two header skeletons, each with 2 square tile skeletons.

---

## 9. Collection page

**References**
- Glow, collection (light), `b2496e7b-2162-46e9-be44-188d2136e244`, https://refero.design/screens/b2496e7b-2162-46e9-be44-188d2136e244 (primary).
- Glow, collection (dark), `d5184d95-0939-4c78-ab09-f160a9017ec9`, https://refero.design/screens/d5184d95-0939-4c78-ab09-f160a9017ec9 (the same screen in dark).

**Anatomy, top to bottom**
1. Sheet handle. **Nav row:** ← left (24 pt); the collection name centred, truncated with "…"; right: ☆ and a share glyph, each in a 32 pt grey circle.
2. **Collection avatar.** A rounded square, 60 pt, radius about 14, left-aligned.
3. **Name**, bold 26 pt, wrapping to 2 lines. Under it, "10,000 Items" (22 pt, grey).
4. **Tabs:** "Items · Sales · Info", three equal-width text tabs. The active one is black with a short 3 pt underline (about 42 pt wide) centred under the label. Inactive ones are grey. A hairline runs under the tab row.
5. **Filter chips:** outlined, fully rounded, 28 pt tall, scrolling sideways ("Background", "Clothing", …).
6. **Grid:** 3 columns, square tiles about 109 pt, 8 pt gaps, radius about 14. A tile whose image hasn't loaded is a flat grey square of the same size.
7. Dark mode is the same layout. The page goes black, the circles and chips go dark grey, and text goes white or grey.

**Copy worth keeping**
- "10,000 Items" (count as the subtitle).
- "Items · Sales · Info" (tabs).

**States visible:** loaded with one loading tile (the first, grey). Light and dark.

**What we take**
- The header stack: small rounded-square avatar, big name, a grey subtitle line.
- The nav row with icon buttons in grey circles at the right.
- 3-column square grid, small gaps, a grey square for an image still loading.
- The dark variant as proof that this layout needs no colour.

**What we change for Logos Kit**
- Subtitle: "You hold N · Floor 5 LGO" (or "Not listed"), 17 pt `text2` (ux-tokens-nfts §2.10). The trust mark sits after the name.
- Right nav buttons: one ⋯ in a 32 pt `surface2` circle (Hide collection · Copy ID · Explorer). No star, no share.
- Tabs: **Your items · Details** (inferred: we show the holder's items, not all 10,000; "Sales" lives in the Market app). The underline is ink.
- No trait filter chips (inferred: LEZ metadata has no standard traits yet).
- Grid: 3 columns at 680 px and up, 2 at 360 px (inferred). Same tile and caption as screen 8.
- Details tab: `InfoRow`s with Collection ID (mono, copy, explorer), "Printed 12 of 100", Creators, Metadata link.

---

## 10. NFT detail

**References**
- Glow, NFT detail, `37f23934-7db6-4e56-99c9-55c407646d91`, https://refero.design/screens/37f23934-7db6-4e56-99c9-55c407646d91 (primary).
- Glow, NFT detail with ⋯ menu, `57cace94-6898-4b16-a212-7aebd9eeef1e`, https://refero.design/screens/57cace94-6898-4b16-a212-7aebd9eeef1e.

**Anatomy, top to bottom**
1. **Media.** Square, full content width (about 344 pt at 16 pt margins), radius about 24. No nav bar over it.
2. **Title row.** Name left, bold 24 pt. Right: ⋯ in a 32 pt translucent circle.
3. **Collection row** (a card in Glow, about 70 pt): a 40 pt rounded-square collection logo, the collection name (17 pt) over "10,000 Items" (grey), and › at the right. Tapping it opens the collection.
4. **Facts.** Three label/value rows, about 30 pt pitch, no separators: "Owner", "Delegate", "Mint Address". Label grey left. Value right, in monospace, short form.
5. **Description.** A full-width paragraph, 17 pt, primary text colour.
6. Hairline, then **"Traits"** (bold 20 pt). In screen 15's scrolled view, traits are chips in a sideways scroll: about 143 × 58 pt, radius 14. Category (grey) and rarity % on the top line, the value bold below.
7. **⋯ menu** (`57cace94`): a popover anchored under the ⋯, growing to the left, about 250 pt wide. Rows 44 pt with hairlines: "Refresh Metadata", "Share Link", "Share Image". Label left, glyph right.
8. The page background is a dark blur of the artwork.

**Copy worth keeping**
- "Refresh Metadata" (menu item).
- "Owner" / "Mint Address" (fact labels).

**States visible:** loaded. Menu open.

**What we take**
- Order: media → name + ⋯ → collection row → facts in mono → description.
- The collection row as the way up to the collection.
- The ⋯ popover with a short list and glyphs on the right, including a metadata refresh.
- Short-form mono values right-aligned against grey labels.

**What we change for Logos Kit**
- A plain page background; no blur of the art.
- Media radius `rCard` 24. Tap opens it full size (inferred). The missing-media placeholder (screen 12) keeps the square.
- **Action tiles** go right under the title row: Send · Make private (public only) / Prove (private only) · Sell or Cancel listing (`ActionTile`, Send in ink) (inferred position: Glow shows no actions above the fold).
- The collection row is a plain row: 40 pt logo, name over "You hold N", › at the right. No card.
- Facts (`InfoRow`): Collection · Item (holding ID, with an ⓘ for "This ID changes when the item moves") · Held in · Metadata · Creators. Master editions add "Can print N more".
- The ⋯ popover (`Popover`): Refresh metadata · Copy item ID · Open in explorer · Hide.
- The description is `text2`, capped at 6 lines with "More" (inferred). Plain text only.
- No traits section unless the metadata has attributes. Then the trait chips are outlined `rRow` chips with no rarity % (inferred: there's no rarity data).

---

## 11. NFT send review

**References**
- Family, send review (dark), `358cccaa-d8b0-4db4-8935-5e6e6c4c85f8`, https://refero.design/screens/358cccaa-d8b0-4db4-8935-5e6e6c4c85f8 (primary).
- Glow, NFT bid receipt, `218e00de-b9f3-4502-87f5-8023758cc8f2`, https://refero.design/screens/218e00de-b9f3-4502-87f5-8023758cc8f2 (how an NFT sits in a detail list).

**Anatomy (Family review), top to bottom**
1. ‹ left, ? in a circle right.
2. A 63 pt avatar circle, left-aligned, with a check badge on its bottom-right.
3. **Heading**, bold 28 pt, left-aligned, 2 lines: "Confirm transaction to 0x1f05····c2d0". The recipient is part of the heading.
4. **Rows**, about 40 pt pitch, label grey left, value right:
   - "Total Value · $36.84"
   - "Send ETH" + an outlined amber "Max" chip · the ETH glyph + amount
   - "From" · an avatar + "Pasta"
5. Hairline.
6. **Fee block:** "$0.64" (bold) over "Fee Estimate ⓘ" (grey) on the left. "Urgent" over "~ 15 Secs" with a speed glyph on the right.
7. A large gap, then 2 centred grey lines (15 pt): "Review the above before confirming. Once made, your transaction is irreversible."
8. **Confirm**, a full-width pill, 48 pt, with a Face ID glyph before the label.

**Anatomy (Glow receipt)**
1. A handle and ←. A centred 80 pt tinted circle with a status glyph.
2. "Placed Bid" (bold 22 pt, centred), the NFT name under it (22 pt grey), and the date (15 pt grey).
3. Full-width hairline, then groups:
   - The marketplace logo (40 pt) with "Bid on" (small grey) over "Magic Eden" (17 pt). Under it, a sub-row: a 24 pt grey glyph in the logo column, "Bidder" (grey), and a mono value on the right.
   - Inset hairline, starting at the text column.
   - **The NFT row:** a 40 pt rounded-square thumbnail, the name (17 pt) over the collection (grey), the amount on the right.
   - Inset hairline. "Network Fee" and "Signature" rows with small grey glyphs.
4. "View Raw Transaction ↗", centred grey link.

**Copy worth keeping**
- "Review the above before confirming." (Family).
- "Once made, your transaction is irreversible." (Family).
- "Fee Estimate" (label).

**States visible:** ready to confirm (Family). Done (Glow).

**What we take**
- The heading carries the verb and the recipient: one bold left-aligned sentence.
- Label/value rows, a hairline, then the fee block apart from what is being sent.
- The NFT appears as a row with a rounded-square thumbnail, name over collection (Glow).
- Inset hairlines that start at the text column between groups (Glow).
- The irreversibility line centred just above the one confirm button.

**What we change for Logos Kit**
- Heading: "Send **Degen Ape #4412** to `7Hk2…9Qpa`". The 63 pt avatar is replaced by the NFT thumbnail, 64 pt rounded square, radius 12.
- Rows (`TxSummary` / `InfoRow`): Item (Glow's NFT row) · To (mono, plus "First time sending here" in `text2` when it applies) · From (account name + Public/Private tag) · What moves: "Single item" or "Entire master edition".
- "Entire master edition" is a warning-tone `Notice` with its `CheckRow` above the button (ux-tokens-nfts §2.12).
- Fee block: the fee in LGO only (no fiat, no speed choice). Private sends add "Takes about 5–8 minutes".
- One extra line when the item has live proofs: "Proofs you made with this item stop working." (`text2`).
- Confirm is an ink pill, with no biometric glyph. The "Max" chip doesn't apply to NFTs.
- After sending, the receipt follows Glow's layout: a centred status circle (ink, no tint), "Sent", the item name in grey, then the same rows and an explorer link.

---

## 12. Missing media placeholder

**Reference**
- Rarible, NFT content missing (web), `216dd664-e4bc-4ab8-8d71-9faefb64d316`, https://refero.design/pages/216dd664-e4bc-4ab8-8d71-9faefb64d316. Only a 1280 × 720 preview is available; the full image is not served.

**Anatomy (inside the media area), centred**
1. The brand mark in a 60 px rounded square (radius about 12) with a soft gradient fill.
2. Two centred lines, 15 px, grey: "We don't have the content for this NFT yet. Check back later."
3. "Refresh": a small light-grey button (about 90 × 44 px, radius 10), black semibold label.
4. Lots of empty space. The media area keeps its size.

**Copy worth keeping**
- "We don't have the content for this NFT yet." (Rarible).
- "Refresh" (one-word retry).

**States visible:** content missing.

**What we take**
- The placeholder fills the media's own box. The tile or hero keeps its square and is never removed.
- A small mark on top, one short reason, one small "Refresh" button, all centred.

**What we change for Logos Kit**
- The mark is the **collection's** initials circle (screen 1's fallback), 40 pt in a tile, 60 pt in the hero. No gradient.
- Two text lines: the collection name + short item ID (primary, 13 pt in tiles, 15 pt in the hero), then the reason (`text2`): "Web images off", "Unreachable", "Invalid metadata", "Too large", "Unsupported type", or "Private: web images never load".
- In tiles: "Refresh" is a glyph-only 28 pt button at the bottom (inferred: the label won't fit at 2–3 columns). In the hero it is a text button. "Web images off" shows "Turn on in Settings" instead.
- Background: `Theme.surface2`, the same radius as a loaded tile.

---

## 13. Proof request sheet

**Reference**
- Glow, connect request sheet, `ca153aec-82eb-409a-839a-a052f5e0ed9e`, https://refero.design/screens/ca153aec-82eb-409a-839a-a052f5e0ed9e.

**Anatomy, top to bottom**
1. **Sheet** from the bottom, top corners about 36. The page behind is blurred and grey.
2. **Header.** The app's logo (20 pt) + its name, bold 22 pt, left. ✕ in a 30 pt grey circle, right.
3. **Pair of avatars**, 40 pt each, overlapping by about 12 pt: the wallet's icon, then the app's icon.
4. **Request sentence**, 20 pt, 2 lines: "Glow wants to connect to" / "My Wallet" + a grey mono short address + ⌄. The account part is a picker.
5. A link glyph + "glow.app" (15 pt grey).
6. **Full-bleed tinted panel** (light grey, edge to edge, about 20 pt padding):
   - "This app will be able to:" (15 pt grey).
   - Two rows, 32 pt pitch: a green ✓ (18 pt) + 17 pt text.
   - "It will not be able to:" (15 pt grey).
   - One row: a grey ✕ + 17 pt grey text.
7. **Buttons**, side by side, equal width, 44 pt, 16 pt gap: "Cancel" (grey fill) and "Connect" (black fill).

**Copy worth keeping**
- "This app will be able to:" / "It will not be able to:"
- "Move funds without your permission" (a ✕ line).

**States visible:** ready.

**What we take**
- Header with the requesting app's identity, then the request as one sentence, then the account it applies to.
- The tinted two-part panel: what it **gets**, then what it **won't get**, with ✓ and ✕ rows. It is the visual centre of the sheet.
- Two equal buttons at the bottom: the safe one on the left, the action on the right.

**What we change for Logos Kit** (we make it distinct from connect and from transaction approvals)
- A **kicker line** above the header: a shield glyph + "MEMBERSHIP PROOF" (13 pt, letter-spaced, `text2`). Connect has no kicker; transaction approvals have a fee block. This sheet has neither.
- Header: "Members' Wall asks for a proof" (bold 22 pt). Under it, the attested app identity line (the same block as connect).
- No avatar pair (inferred: the shield kicker does that job).
- The panel's headings are **"They'll learn"** and **"They won't learn"**. The rows are literal values, with the values in bold: "Someone holds an item from **Logos Kit Pass**", "The proof is for **members-wall:post**", "It's valid until **14:32**" / "Which wallet or account", "Which item", "Your balances or other holdings".
- ✓ glyphs are **ink**, not green. ✕ glyphs and the "won't learn" text are `text2`. `Permissions.qml` draws its checks in `Theme.ok` today; this sheet needs `Theme.text`.
- Under the panel: a "Using" row (the private NFT; › opens a picker when there is more than one), the anonymity line, and the time line. The few-holders case is a `warn` `Notice`.
- Buttons: **Decline** (secondary, left) · **Prove** (ink, right). Prove arms after 500 ms. The sheet is `dismissable: false`.

---

## 14. Connected apps (per-capability revoke)

**References**
- Glow, Connected Sites, `8ea91cb8-01bb-4ec2-b284-03d5315166a4`, https://refero.design/screens/8ea91cb8-01bb-4ec2-b284-03d5315166a4 (primary: the list).
- iOS Health access sheet, `b91a5b52-3a71-4b40-85d5-8c1796ff8dcf`, https://refero.design/screens/b91a5b52-3a71-4b40-85d5-8c1796ff8dcf (the per-capability page). Refero files it under the app "Gentler Streak": it is Apple's Health permission sheet shown inside that app.

**Anatomy (Glow list)**
1. A sheet with a handle. ← left, "Connected Sites" centred (17 pt semibold).
2. Section header "The Wall" (17 pt bold), left. Apps are grouped under it.
3. **App row:** a 40 pt app logo with a 16 pt verified badge (✓ in a circle) on its bottom-right; the name (17 pt) over the domain (15 pt grey); on the right, a compact fully rounded "Remove" button (about 76 × 30 pt, red fill, white label).
4. A footnote under the list, 15 pt grey, 3 lines, explaining what removing does and that you can reconnect.

**Anatomy (Health access)**
1. Nav: "Don't Allow" left (accent), "Health Access" centred, "Allow" right (disabled grey).
2. The app icon, 80 pt rounded square with a hairline border, centred. "Health" bold 34 pt. A centred sentence naming the app and what it wants.
3. "Turn On All": a full-width grouped button, accent text.
4. A section header in uppercase grey, 13 pt: "ALLOW “GENTLER STREAK” TO WRITE".
5. A **grouped list** (radius about 10): rows 44 pt with a 20 pt glyph, a 17 pt label, and a toggle at the right. Separators are inset to the label column.
6. A footnote under the group (13 pt grey).
7. A second section, "…TO READ", with the same structure.

**Copy worth keeping**
- "Remove" (Glow's per-row action).
- "You can always reconnect to it." (Glow footnote).
- "Allow … to read" (Health's section-header shape).

**States visible:** one connected site (Glow). All capabilities off (Health).

**What we take**
- List page: apps grouped under a header, each row with logo + verified badge, name over domain, and one compact action at the right edge.
- A footnote that says what removal does and that it can be undone by reconnecting.
- Detail page: Health's structure. Section headers name the kind of access, one row per capability, one control per row, a footnote per section.

**What we change for Logos Kit**
- **List** (one row per app): 40 pt logo + verification badge (ink check, not green) · name over "3 permissions · last used 6 Oct" (`text2`) · › opens the app page. No per-row Remove on the list (inferred: revoke lives on the detail page, as the spec asks).
- **App page:** header = Health's centred 80 pt icon + name + one sentence ("Connected since 6 Oct"). Then sections:
  - "Can see": account and NFT visibility rows.
  - "Can ask for": approvals and membership proofs.
  - Each row: the capability in plain words (ux-tokens-nfts §2.15) over "Granted 6 Oct · used 14:02" (`text2`). At the right, a compact **Revoke** button: outlined, ink text, 30 pt, fully rounded.
- No toggles (inferred: revoking is one-way; granting happens only through a connect request).
- Rows sit on the page background with inset hairlines. Health's grey grouped surface is dropped.
- Proofs log row: "Shared 3 proofs · last 6 Oct 14:02".
- Footer: **Disconnect app**, a full-width secondary button with ink text, then Glow-style footnote copy. No red anywhere.

---

## 15. Market (listing, buy sheet, floor price)

**References**
- Coinbase, NFT listing (dark), `be0166cf-626f-46e6-a721-bcbe4808b12f`, https://refero.design/screens/be0166cf-626f-46e6-a721-bcbe4808b12f (primary: an item for sale).
- Family, NFT with floor and last sale, `ca3a984a-b323-4773-ae59-8f8434339a29`, https://refero.design/screens/ca3a984a-b323-4773-ae59-8f8434339a29.
- Glow, NFT traits and recent activity (dark), `49846bfe-bcf5-49d9-9d0a-f9a871c66988`, https://refero.design/screens/49846bfe-bcf5-49d9-9d0a-f9a871c66988.

**Anatomy (Coinbase listing), top to bottom**
1. ← left, the item name centred.
2. **Media**, square, about 327 pt, radius about 15.
3. **Price block:** "Best Price" (15 pt) over the price, bold 24 pt ("1.67 ETH"), left. The fiat equivalent in grey on the right of the same line.
4. Where the buy button would be: one grey sentence, "Buying is not currently available on iOS". It is the disabled state, written out.
5. **Rows**, about 56 pt pitch: a 20 pt glyph + "Chain" left, the value right. A glyph + "Owner" left, the short address (grey) right.
6. A bottom tab bar (not ours).

**Anatomy (Family floor)**
1. A handle. The media card.
2. Title bold 26 pt, truncated, then ★ and ⋯. Under it, the collection (a small grey logo + grey name).
3. Hairline. **Two centred stat columns** split by a vertical hairline: "Last Sale ⓘ" over "No Sales Yet", and "Floor Price ⓘ" over "No Floor Price". The empty values are grey.
4. "Owned by" pill (as screen 5). "Description" header with a glyph, then a paragraph.

**Anatomy (Glow activity)**
1. Trait chips in a sideways scroll (screen 10).
2. "Recent Activity" (bold) with "View All ›" (grey) at the right of the same line.
3. Rows, 58 pt pitch: a hammer glyph · "Bid by 6ARSY…S2jBK" over "Magic Eden · Mon 12:53 PM" · on the right, "17.83 SOL" over "$956.97".

**Copy worth keeping**
- "Best Price" (label over the price).
- "No Floor Price" / "No Sales Yet" (empty stat values).
- "View All" (activity link).

**States visible:** buying unavailable (Coinbase). No sales and no floor (Family). Bids listed (Glow).

**What we take**
- The listing reads top-down: media → price label over a big price → the buy action (or why it is unavailable) → chain/owner rows.
- Floor and last sale as two centred stat columns with an empty value written out ("No Floor Price"), never "0".
- Activity as rows: a verb with a short address, source · time, and the amount on the right; "View All ›" in the section header.
- A disabled action is replaced by a sentence that says why.

**What we change for Logos Kit**
- **Listing (item page in the Market app):** media → "Price" (15 pt `text2`) over "5 LGO" (32 pt tabular, primary). No fiat on the right. Below: the **Buy** ink pill, full width. When it can't be bought, the sentence replaces it (Coinbase): "You can't buy your own listing", "Not enough LGO".
- Rows: "Seller" (mono short address) · "Collection" › · "Listed" (date). No chain row: there is one chain.
- **Collection header in the Market:** Family's two stat columns, "Floor" and "Listed", with values in LGO or "Not listed" / "None" in `text3`. The ⓘ glyphs open a one-line `Tooltip`.
- **Buy sheet** (inferred: none of the three references shows one; it is built from screen 11's review layout + Coinbase's price block):
  1. The heading "Buy **Degen Ape #4412**" with the 64 pt thumbnail.
  2. Rows: Price · Fee · Total (bold) · **Pay from**, a Public | Private `SegmentedControl`.
  3. Private adds "The item arrives in a new private vault. Takes about 5–8 minutes."
  4. The ink **Buy** pill. Then the proving pipeline (`Pipeline`) in the same sheet.
- **List sheet** (inferred, the same layout): a price `AmountField` in LGO · "Your public account `7Hk2…9Qpa` is shown as the seller." · "Listing ends any proofs made with this item." (`text2`) · Fee · **List** in ink.
- Activity rows (Glow) for sales and listings. Amounts are LGO only, in `Theme.text`.
- Race states ("Someone bought it first. You weren't charged.") replace the button area with a `Notice` and a "Back to listings" button.

---

## Decisions that span screens

1. **Numbers live on the right edge.** Every list (tokens, activity, review rows, listings) puts the amount right-aligned in tabular figures. With no fiat, the token row's right column is the token amount. This is Family's eye-line, without the fiat value.
2. **Status is a word, not a banner.** Trust and risk show as a word after the name and as one row value in `Theme.warn` (Glow). Only a `warn` `Notice` above the primary action escalates it (UGLYCASH). Nothing else on these screens is coloured.
3. **Hidden things stay findable in place.** The list ends with a text row "Hidden · Unknown (N) ›" (Family web). In Manage tokens, hidden rows stay in the list, dimmed with an eye-slash (Family edit). Nothing disappears without a count.
4. **The media square is sacred.** Tiles and hero media always keep their square, radius and size. Loading is a flat grey square (Glow). Failure is a placeholder inside the square (Rarible). An NFT is never dropped from a grid.
5. **One sheet shape, three distinct heads.** Connect, proof request and approvals share the sheet, the two-part panel and the two-button footer (Glow). They are told apart by their heads only: connect has the app pair, proofs have the shield kicker and "They'll learn / They won't learn", and approvals have the fee block. Reviews put the verb and the target in one bold left-aligned heading (Family).
