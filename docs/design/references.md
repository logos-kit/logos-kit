# Logos Kit — design reference set

Research date: 2026-09-26. Every claim has a source. Where I read the product's source code, the file path is given. Anything I inferred rather than saw is marked **(inferred)**. Screenshots are in `refs/` (16 files).

Evidence quality varies. Family, ConnectKit, Porto, Zashi/Zodl and Penumbra are well covered: I read their written design notes, their source code or their shipped UI strings. Phantom, Zerion, Uniswap, Rabby and Backpack come from App Store and marketing screenshots only. Privy comes from its docs API. For Base app, Dynamic, Daimo, Aztec and Railgun I found little that shows UI detail (see "Gaps" at the end), so I make no claims about their UIs.

---

## 1. Family (iOS app) + Benji Taylor's "Family Values"

Sources: https://benji.org/family-values (the post and its 55 poster frames at `https://benji.org/media/family-values/NN.png`), and Family's App Store screenshots (https://apps.apple.com/us/app/family-crypto-wallet/id1606779267).

1. **Tray system (sheets that grow and shrink with their content).** Temporary actions (confirm, warnings, options, "refuel gas") open as a *tray*: a card with rounded corners, inset from the screen edges, sitting on top of the current screen. The screen behind stays visible, so the user keeps their place. Rules Benji states:
   - Each tray in a sequence has a **different height**, so the change is unmistakable. They sometimes rewrite copy just to make the heights differ.
   - Each tray has **one job**: one piece of content or one primary action.
   - The top-right icon of a tray means **close** on the first tray and **back** on later trays.
   - A tray takes on the theme of the flow it opens from (a dark flow gets dark trays).
   - A tray can open *out of* the button that triggered it (for example, swap approval unfolding from the swap UI), and it can grow into a full screen.

   Refs: `refs/family-refuel-simulation.jpg`, `refs/family-pending-tray.jpg`.
2. **Text morphing on the CTA.** "Continue" becomes "Confirm" through a morph of the shared letters ("Con…"), so the user notices they've reached the step that commits funds. The same technique updates count labels ("Add 3 wallets"). Source: benji.org/family-values, "Fluidity" section.
3. **Shared elements persist between screens.** If an element stays on screen from one step to the next, it must not be duplicated or re-rendered; it moves. The amount typed on the keypad travels into the confirm screen, which "gives them confidence that the amount entered is indeed the amount being sent." After the user confirms, **a spinner flies into the Activity tab** to show where the pending transaction now lives. Speed-up moves its spinner onto the original pending tray. Tab switches slide in the direction of the tab tapped ("we fly instead of teleport").
4. **Send screen anatomy** (`refs/family-send-amount.jpg`):
   - Title "Send" with an ✕ close button.
   - A recipient pill: "To  James".
   - A **huge fiat amount** (~64pt, heavy weight, small superscript "$").
   - Below the amount, the token equivalent with a ⇅ toggle.
   - A token-picker row with a "Use Max" chip.
   - A full custom numeric keypad.
   - A pill-shaped full-width primary button.

   While typing, **commas slide into place** as the number grows. Entering more than the balance triggers an easter egg.
5. **Confirm / pending / completed tray anatomy** (`refs/family-confirm-tray.jpg`, `family-pending-tray.jpg`, `family-completed-tray.jpg`):
   - A token glyph with a status badge.
   - Title "Confirm transaction to James".
   - A key–value list: Total Value, Send ETH, From (avatar + name).
   - Fee and speed ("$0.85 · Normal ~45 secs").
   - Fine print: "Review the above before confirming. Once made, your transaction is irreversible."
   - The CTA "Confirm" with a Face ID glyph.

   After submit, the same tray becomes a **receipt card**:
   - The amount sits inside a faint dashed/dotted frame.
   - A full-width **status pill**: blue tint with a spinner and "Pending", which becomes green tint with a ✓ and "Completed", each with an ⓘ.
   - Then rows for Wallet, Network Fee and Chain, each with a small leading icon.
6. **Risk and simulation before signing** (`refs/family-refuel-simulation.jpg`, `refs/family-know-what-youre-signing.jpg`):
   - Domain verification: "This domain has been verified", in a blue info pill.
   - For a malicious site, a **red banner** reading "This domain is unsafe and malicious. Interacting is not recommended." plus a "+3 Additional Warnings / View All" row.
   - **"Estimated Wallet Changes"**: Send in red (−) and Receive in green (+) rows with token icons and amounts.
   - Then Network, Fee Estimate ("up to $1.82") and Estimated Time ("~45s").
   - Cancel is a grey pill and Continue a coloured pill, side by side.
7. **Token list and balance** (`refs/family-token-list.jpg`):
   - Wallet avatar and name as the header, with "Tokens | Collectibles" segmented text tabs and the total at top right ($589.55).
   - Row anatomy: 36px round token logo · name (semibold) over quantity (secondary grey) · fiat value (right) over % change (tiny, red/green).
   - Pending activity is pinned under a **"Pending ⓘ"** header above the dated groups ("This Week", "Yesterday").
8. **Delight on rare events only** (Benji's "Delight-Impact Curve"): confetti after a backup, a ripple on the QR code, a shimmer while **stealth mode** hides balances ("values are concealed, they continue to update discreetly in the background").

Type: Family uses the system font (SF Pro) with very heavy display weights for amounts **(inferred from screenshots; not stated)**.

## 2. ConnectKit (Family's web connect kit) — read from source

Source: https://github.com/family/connectkit, `packages/connectkit/src/components/Common/Modal/styles.ts` and `styles/index.ts`.

1. **Measured height morph.** The modal measures each page and writes `--width` and `--height`. The box (an absolutely positioned `:before` that carries the background, radius and shadow) animates `height`/`width` over **200ms `cubic-bezier(0.25, 0.1, 0.25, 1)`**, and the inner container clips with `overflow: hidden`. The background resizes; the content never stretches.
2. **Page transitions use depth, not slides.** Going forward, the new page runs `FadeInScaleDown` (opacity 0→1, scale 1.1→1) while the old page runs `FadeOutScaleUp` (1→1.1, opacity →0) over 200ms. Going back uses the reverse pair (scale 0.85). The outgoing page becomes `position:absolute; pointer-events:none` so both pages overlap during the crossfade.
3. **Mobile bottom sheet with overshoot.** Enter uses `translate3d(0,100%,0)→0` over **300ms `cubic-bezier(0.15, 1.15, 0.6, 1)`** (the y1 > 1 gives a slight overshoot), with a 32ms delay. Exit is a 130ms opacity fade. On mobile, page changes are plain fades.
4. **Press feedback** on every button: `transition: background-color 200ms ease, transform 100ms ease` (with a scale-down on `:active`). Default modal radius is 20px, and the controller/header bar is 64px tall.
5. Font stack: system (`-apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica…`), overridable with `--ck-font-family`. Themes (`rounded`, `midnight`, `nouns`, `retro`, `web95`) are CSS variable sets (`styles/themes/*.ts`).

## 3. Porto (Ithaca) — passkey dialog, read from source

Source: https://github.com/ithacaxyz/porto (porto.sh now redirects there): `apps/ui/src/Frame/Frame.tsx`, `apps/theme/porto-theme.ts`, `apps/dialog/src/styles.css`, `apps/dialog/src/routes/-components/*`.

1. **Frame modes.**
   - `dialog/floating`: a **360px** card pinned `top: 16px`, like a system prompt dropping from the top.
   - `dialog/drawer`: up to 460px, flush to the bottom with no bottom radius or border.
   - `full`: a full page.

   The frame measures its content and reports `height + 33` (a 32px frame bar plus a 1px border) to the host, so the **iframe resizes to fit the content**. The backdrop is `rgba(0,0,0,0.5)`.
2. **Frame bar = provenance.** A slim 32px bar shows the requesting site's icon and domain with a `lucide/badge-check` verified mark, plus an ✕. The user always sees *who* is asking, separately from *what* is asked.
3. **Semantic colour roles, not a palette.** The theme defines roles such as `baseBackground / baseAltBackground / basePlaneBackground`, `baseContent / baseContentSecondary / baseContentTertiary / baseContentPositive / baseContentNegative / baseContentWarning`, `badge{Info,Positive,Negative,Warning,Strong}{Background,Content}`, `field{Background,Border,FocusedBackground,ErrorBorder,…}`, `primary/secondary/distinct/strong/disabled {Background,Border,Content}`, `frame{Background,Border,Radius}`, `separator` and `focus`, each with a light and a dark value. Radii: `radiusSmall 5`, `frameRadius 14`. Dialog base text is **15px / 1.325**, button height 40px, default radius 8px.
4. **One component for every request.** `ActionPreview` wraps each request type (Send, Swap, Approve, SignMessage, GrantPermissions…). It refetches quotes on each new block, and when funds fall short it swaps in an inline **"You need …" deficit → Add Funds / Apple Pay** screen *inside the same frame* instead of failing.

## 4. Phantom

Source: App Store screenshots (https://apps.apple.com/us/app/phantom-trading-wallet/id1598432977), phantom.com. Ref: `refs/phantom-home-token-list.jpg`.

1. **Home hierarchy:**
   - Top pills "Home / Trade / Explore", with the active one filled in lilac.
   - A "My Wallet ⌄" selector, then the **balance (~40pt bold)** and "+$534.56 Today" in green below it.
   - A "Cash" row, then a **Tokens** list.
2. **Token row:** round logo · name over quantity (grey) · fiat value over change (green/red), on a near-black background with no dividers.
3. **Brand colour is used sparingly:** lilac/purple appears on the active pill and on marketing surfaces. Inside the app, content is monochrome **(observed)**.
4. **Risk:** the site claims "Scam detection flags malicious transactions instantly" (phantom.com). I couldn't capture a screenshot of the confirm UI; don't copy details that aren't evidenced here.

## 5. Rainbow (app) / Zerion / Uniswap wallet — balance typography

Sources: App Store screenshots (Zerion id1456732565, Uniswap id6443944476, Rainbow id1457119021). Refs: `refs/zerion-portfolio-greyed-decimals.jpg`, `refs/uniswap-swap-input.jpg`.

1. **Tinted decimals.** Zerion ("$41,249**.34**") and Uniswap ("$22,323**.75**") show the whole-number part in full-contrast content colour and the **cents in a tertiary grey**. The main number reads fast and precision is still there.
2. Zerion: the change line sits under the balance ("+5.87% ($2,286.15) Today") in green. "My Wallets" rows each show a wallet avatar, name, value and % change. The portfolio chart has 1D/1W/1M/1Y/All period chips.
3. Uniswap swap input: big numeric amount (~36pt) on the left, token chip right ("ETH ›"), with the fiat value and "Balance: 3.789 **Max**" below; a small ↓ switcher in a square between the two cards.
4. Rainbow app today is a trading app (https://rainbow.me: "Trade any market from your phone"). Its App Store listing has only 2 screenshots, not enough to extract wallet patterns.

## 6. Rabby — pre-sign simulation

Sources: rabby.io product images (`static-assets.rabby.io/files/*.png`) and App Store (id6474381673). Refs: `refs/rabby-send-simulation-gas-warning.png`, `refs/rabby-connect-flagged-dapp.png`, `refs/rabby-home-balance.jpg`.

1. **The balance change is the headline of the sign screen.** "Send Token" shows **"− 4,356.12 USDC" in red** at the top with "≈$4,356.12" at the right, then key–value rows for Chain and Send to (a truncated `0x5853…eb85`).
2. **A sticky footer carries the fee and blocking checks:** gas cost ("$1.12"), speed ("Normal ⌄"), Sign / Cancel buttons, and an inline blocking reason under them ("Gas balance is not enough"). **Sign is disabled** until the reason clears.
3. **Connect screen reputation rows:**
   - dapp favicon + full URL.
   - "Listed by" (logos of the lists it appears on).
   - **"Flagged by Rabby: Yes"** with a red shield badge.
   - Connect disabled/tinted.
4. Twitter testimonials on rabby.io say the product's reputation rests on "simulates and shows you what will happen after you sign any transaction". Simulation is the brand.

## 7. Privy — embedded wallet confirm UI (docs API)

Source: https://docs.privy.io/wallets/using-wallets/ui-components.

1. The sign prompt defaults are **title "Sign message"**, description **"Signing this message will not cost you any fees."**, and button **"Sign and continue"**. It reassures the user about cost before they act.
2. Send transaction takes these options:
   - `description`
   - `buttonText` (default "Submit"/"Approve")
   - `transactionInfo { title, action: 'Buy NFT', contractInfo { name, url, imgUrl } }`, shown as a **"details" accordion**
   - `successHeader` ("Transaction complete!") and `successDescription` ("You're all set.")
   - `isCancellable`

   The pattern is **human action label first, raw details collapsed**, and a dedicated success screen.
3. `showWalletUIs` can hide the confirmation completely for low-risk actions. Only low-risk actions should skip the confirm step.

## 8. Zcash — Zashi (now "Zodl")

Sources: shipped UI strings in https://github.com/Electric-Coin-Company/zashi-ios (`secant/Resources/Localizable.xcstrings`) and App Store screenshots (id1672392439). Refs: `refs/zashi-home-transparent-detected.jpg`, `refs/zashi-one-click-shielding.jpg`, `refs/zashi-hidden-balance.jpg`.

1. **Two-state vocabulary, and the private state is the default.** Strings include "Private" / "Not Private", "Shielded (Spendable)", "Transparent", "Spendable Balance", "Pending", "All your funds are shielded and spendable." Addresses carry a type label: "Zcash Shielded Address (Rotating)" vs "Zcash Transparent Address (Static)", with the note "For privacy, always use shielded address."
2. **The non-private balance is handled as an alert with one fix.** On the home screen, a purple banner reads **"Transparent Balance Detected"** with the amount and a **"Shield"** button (screenshot `zashi-home-transparent-detected.jpg`). The copy: "Shield your transparent ZEC to make it spendable and private." The marketing line: "Privacy starts with 1-click shielding."
3. **Pending is split into sub-states:** "Pending receipt of change from a prior transaction." Shielding has its own statuses: "Shielding" → "Your coins are getting shielded" → "Shielding Pending" → "Shielded!". Proof generation is named in the UI with progress: "Building vote proof (%@/%@)…", and errors are specific ("Proof generation failed. Please try again.").
4. **Home anatomy:**
   - Account switcher, ZEC balance (large, with the ƶ glyph), fiat value below.
   - Four round action buttons (Receive / Send / Pay / Swap).
   - An Activity list whose rows include "Shielded" as its own transaction type.
   - An **eye icon** for hide-balance: the balance shows as "ƶ -----".

   Syncing is an explicit state ("Syncing", "Keep screen on while syncing", "Older wallets can take hours").
5. It teaches the privacy costs of ordinary actions, for example that querying exchange rates "an exchange might be able to see…", and that value leaving the pool "publishes an amount on-chain".

## 9. Penumbra — Prax + minifront

Sources: https://praxwallet.com, https://github.com/penumbra-zone/web (`apps/minifront/src/state/helpers.ts`, `packages/ui-deprecated/lib/toast/transaction-toast.tsx`).

1. **The proving lifecycle is a persistent toast with a real progress bar.** `planBuildBroadcast` runs plan → build → broadcast → detect. The toast (`duration(Infinity)`) shows:
   - **"Building {label} transaction"**, with a `<Progress>` bar driven by `Math.round(status.progress * 100)` from the proof builder.
   - Then **"Emitting {label} transaction"**, with a shortened tx hash.
   - Then **"Waiting for confirmation"**.
   - Then **"{label} transaction succeeded! 🎉"**, with detection height and an explorer link.
   - Or one of the distinct end states "Transaction canceled", "Not logged in", "{label} transaction failed".
2. Vocabulary: **Shield / Unshield**, "Shielded Balance", "Shielding Activity", "Shield Assets". Onboarding step 3 of Prax is literally "Shield Your Assets".
3. Prax states where the work happens: "All actions, including encryption, **proof generation**, and balance updates, are handled by your local device" (praxwallet.com). Local proving is presented as a benefit, not hidden.

## 10. Railgun / Railway

Sources: https://railgun.org, https://railway.xyz.

1. The private address type has its own prefix: **"0zk address"**, used as a label and as a token prefix in stats ("0zk USDC Volume").
2. The verbs match the others: **Shield** ("Privatize your existing assets by shielding into a private 0zk address"), **Private Transfers**, and Unshield. Private sends "transfer value without revealing sender, recipient, amount, or token type". This spells out *what* is hidden.
3. Compliance is offered as positive features: Viewing Keys ("read only… reveals origin of funds") and Private Proofs of Innocence. No proving UI screenshots were available **(gap)**.

## 11. Backpack, Base app, Dynamic, Daimo, Aztec — gaps

- Backpack (App Store id6445964121): exchange-style, with a red/white editorial theme. Not a wallet-confirm reference.
- Base app / Coinbase Wallet (id1278383455), Dynamic (dynamic.xyz), Daimo (now a stablecoin ramp, daimo.com): nothing concrete about confirm or pending UI was capturable in this pass. Daimo's deposit widget shows **time estimates per method** ("Verify ID + selfie ~5 min · Instant", daimo.com), a useful pattern for our "private send takes minutes".
- Aztec: no public wallet UI captured. Don't cite it.

---

## What the best do that v1 didn't — prioritized moves for Logos Kit

1. **Build the modal on a measured-height sheet, not fixed pages.** Measure each step's content and animate the container's height and width (ConnectKit: 200ms `cubic-bezier(.25,.1,.25,1)` on a background layer, content clipped). Give each consecutive step a **visibly different height** (Family rule). For a more physical feel, use a spring (for example `type: spring, bounce: 0.15–0.2, duration 0.35s`, **inferred**, not taken from a source). Refs: §1.1, §2.1.
2. **Navigate with depth and direction.** Forward: the new step scales 1.1→1 and fades in while the old one scales up and fades out. Back: the reverse (ConnectKit §2.2). The header's ✕ becomes ← on step 2+ (Family §1.1). Tab and segment switches move in the direction of the tapped item (Family §1.3).
3. **Private account = the default, calm state; public = the flagged state.** Borrow Zashi's framing: private balances are labelled "Private · Spendable", and any **public** balance shows a single banner, "Public balance detected · 12.4 LOGOS · [Make private]", which opens the shield flow (Zashi §8.2). Never style the two as two equally weighted tabs.
4. **Proving is a first-class, persistent, measurable state.** After Confirm, the tray morphs into a receipt card whose status pill runs **Preparing → Proving locally (progress bar, % from the prover, with an "≈ 2–4 min" estimate) → Submitting → Waiting for confirmation → Sent** (Penumbra toast §9.1, Family pill §1.5, Daimo time estimates §11). Distinct end states: Cancelled / Failed (with the proving error text) (Penumbra, Zashi §8.3).
5. **The pending send flies to Activity and can be left.** When the user closes the tray mid-prove, animate a small spinner (or ring showing % done) into the Activity tab or the account button, and keep a **"Pending" group pinned above dated history** (Family §1.3, §1.7). "You can close this. Proving continues on this device" (Prax's local-first framing §9.3).
6. **Morph the CTA label at the commit point.** "Continue" becomes "Confirm" (or "Review" becomes "Prove & send" for private) with a shared-letter text morph, and the amount element *travels* from the input to the confirm tray instead of being re-rendered (Family §1.2–1.3).
7. **Put the balance change first on the confirm tray.** First line: "− 25.00 LOGOS" in the negative role colour (plus "+ … " rows for receipts, as in Family's "Estimated Wallet Changes"). Then key–value rows: To, From (Private/Public account chip), Network fee, **Visibility** ("Amount, sender and recipient hidden" for private, spelled out like Railgun §10.2), Estimated time. Then the irreversible fine print, then the CTA (Rabby §6.1, Family §1.5–1.6).
8. **Show blocking reasons inline and disable the CTA.** Examples: "Not enough public balance for fee", "Prover still downloading (43%)". Put them under the button in a sticky footer; never use a modal error (Rabby §6.2). Handle a shortfall inside the same frame with a "You need …" → add funds/shield step (Porto §3.4).
9. **Separate provenance from content.** A slim top bar shows the requesting app's icon, domain and verified badge (or an unverified/flagged treatment with a red banner and "+N warnings") on every request (Porto §3.2, Family §1.6, Rabby §6.3).
10. **Replace the palette with semantic colour roles.** Define `base / baseAlt / plane`, `content / secondary / tertiary`, `positive / negative / warning / info` (each as background + content), `field*`, `primary / secondary / strong / disabled`, `frame*`, plus **two privacy roles**: `private` (a single dedicated hue used *only* for private state: badge, pill and shield CTA) and `public` (neutral grey, never alarming). Brand colour goes on the primary CTA and active states only (Porto §3.3, Phantom §4.3).
11. **Balance typography.** Large numbers use tabular figures at weight 600–800; **cents or decimals in the tertiary colour**; fiat and token toggle underneath with ⇅. Commas and digits animate position as the user types (Zerion/Uniswap §5.1, Family §1.4). For a font, choose one sans with tabular numerals (for example Inter Display or Geist, **my suggestion**; the references mostly use SF Pro/system per §1, §2.5).
12. **Token and account row anatomy.** 36–40px round logo · name (semibold) over quantity (secondary) · fiat (right, semibold) over change (tiny, positive/negative). No dividers; 12–14px vertical rhythm. Add a small lock glyph or a "Private" micro-badge on rows held privately (Family §1.7, Phantom §4.2, Zashi §8.4).
13. **Privacy-aware hide-balance.** An eye toggle masks balances as "•••••" (Zashi's "ƶ -----"). Use Family's **shimmer** on masked values to show they are still live (§1.8, §8.4).
14. **Reassurance microcopy at each decision.** "Signing this won't cost fees" on signatures (Privy §7.1), "Proving happens on this device; nothing leaves until you send" (Prax §9.3), and address-type labels "Private address (rotating) / Public address" (Zashi §8.1).
15. **Save delight for rare moments.** Confetti or a sequin effect on the first successful private send or the first shield, a ripple on the QR, and nothing on routine sends beyond crisp motion (Family's Delight-Impact Curve §1.8).

### Screenshot index (`refs/`)
family-send-amount, family-confirm-tray, family-pending-tray, family-completed-tray, family-refuel-simulation, family-token-list, family-know-what-youre-signing, phantom-home-token-list, zerion-portfolio-greyed-decimals, uniswap-swap-input, rabby-home-balance, rabby-send-simulation-gas-warning, rabby-connect-flagged-dapp, zashi-home-transparent-detected, zashi-one-click-shielding, zashi-hidden-balance.
