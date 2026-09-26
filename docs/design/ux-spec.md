# UX spec (draft v0, S0)

The single source for **flows, states and copy**. The QML (Basecamp), React (web) and React Native renderers implement this spec. Visual tokens come from `@logos-kit/theme`. Copy is plain, honest and short.

**Status words are exact.** "Not confirmed" never means "Not sent". An unknown value renders as "—", never as 0.

---

## 0. Global rules

- **States.** Every async surface has `idle`, `loading`, `success`, `empty`, `error` (with a retry action) and, where relevant, `offline` and `stale`.
- **Security rendering.** Untrusted strings are shown as plain text: dApp names, package metadata, memos, testimonial text and token names.
- **Logos.** Use the real Logos mark and token logos; the fallback is a deterministic identicon. No generic glyph icons where a logo exists.
- **Widths.**
  - Phone: about 360 px.
  - Compact: below 680 px.
  - Desktop: 1024 px and up.
- **Sheets.** Sheets hold focus, close on ESC unless busy, and stay open until the backend answers. Errors appear inline.
- **Motion.** 150–350 ms, overshoot curve `cubic-bezier(.15,1.15,.6,1)`, and `prefers-reduced-motion` disables it.
- **Amounts.** Always shown with the token symbol and logo. Full precision is available on hover/tap. Numbers are right-aligned.

---

## 1. Onboarding (first run)

| Step | Screen | Primary action | Other actions | Notes |
|---|---|---|---|---|
| 1 | **Welcome**: Logos mark, "Logos Kit, a wallet for the Logos Execution Zone" | Create wallet | Restore from recovery phrase | Shows "Testnet" as a badge |
| 2a | **Set password**: strength meter, confirm field | Continue | Back | Password unlocks this device only |
| 3a | **Recovery phrase**: 24 words, hidden until "Reveal" | I've saved it | Copy (with a warning) | "Anyone with these words controls your funds." |
| 4a | **Confirm phrase**: pick words 3, 11 and 19 | Confirm | Back | Wrong word → shake, "That's not word 11." |
| 5 | **Accounts ready**: shows **Public account 1** and **Private account 1** | Get test funds | Go to wallet | The private account shows "Private: balance and history are only visible to you." |
| 2b | **Restore**: paste or enter 24 words, then a birthday (date) | Restore | Back | "Restoring… x%. Funds found so far are already usable." |

**Unlock** (returning users): password field → Unlock. Five wrong tries → a 30 s cooldown. There's a "Forgot password? Restore from recovery phrase" link.

---

## 2. Home / assets

- **Header:**
  - account picker: identicon, label, and a kind badge (◉ Public / 🛡 Private, shown as icons, not emoji);
  - network badge: the Logos mark plus "LEZ testnet".
- **Balances:**
  - native, then tokens, each with its logo, amount and symbol;
  - private accounts show three buckets: **Spendable / Pending / Locked by a proof in progress**;
  - while syncing, a private account shows **"Syncing… block 25,947 of 26,102"** and never a fake 0.
- **Actions:** Send · Receive · Get test funds.
- **Empty:** "No tokens yet. Get test funds to start." [Get test funds]
- **Offline:** a top banner reads "Can't reach the sequencer (testnet.lez.logos.co). Retrying…"; balances show "last updated 2 min ago".

---

## 3. Send

- **Fields:** From (account picker), To (address or private receive code), Asset (logo picker), Amount (with a Max button).
- **Checks before review:**
  - the fee payer has enough balance;
  - the recipient format is valid;
  - token holding checks (these depend on the program).
- **Review sheet:** reuses the Approval sheet layout (§6), shows the **estimated fee**, and the Send button arms after 500 ms.
- **Public send:** Submitting → Waiting for block (~15–60 s) → **Included**. The outcome shows as "Confirmed" when the own-account invariant holds, otherwise "Not confirmed yet".
- **Private send / shield / deshield:** shows the proving flow (§7).
- **Errors:**
  - Insufficient funds: "You need 0.0021 LEZ more to cover the fee."
  - Rejected by the sequencer: shows the code, a "Copy details" button and a Retry button.

---

## 4. Receive

- **Public:** QR code (Rectangle-drawn in QML), full address, a copy button, and "Share".
- **Private:**
  - the receive code: QR (binary, ECC-L), a copy link, and a **fingerprint** ("ends K7-QX");
  - **New code**: rotates to a new key;
  - **Request amount**: builds a payment request link.
  - Explainer: "Senders need this code to pay you privately. It doesn't reveal your balance."

---

## 5. Connect (dApp → wallet)

### Basecamp (intent `lez.wallet.connect`)

1. The shell chooser opens (drawn by the shell). The user picks Logos Kit.
2. **ConnectSheet**:
   - **Requested by:** the attested `requesterName` in monospace, plus the package display name, version and repository, labelled "Unsigned: Basecamp can't confirm who published this app".
   - **Asks for:** "See your selected accounts and balances" and "Propose transactions for your approval".
   - **Account picker:** Public and Private tabs with multi-select. Selecting a private account requires a separate checkbox: "Let this app see this private account's balance."
   - Buttons: [Connect] (arms after 500 ms) · [Cancel].
3. Responses:
   - Connect → the intent answers `ok`, and the shell returns the user to the dApp.
   - Cancel → `cancelled`.
4. A **busy guard** applies while another request is open: "Finish or cancel the open request first."

### Web / React Native (modal)

The connection states are those listed in `parity-ledger.md`:
- **Connecting:** "Opening Logos Kit…", with a spinner around the logo.
- **Expiring:** a 45 s countdown.
- **Rejected:** "Request declined" [Try again].
- **Request pending:** "A request is already open in your wallet" [Focus wallet].
- **Unavailable:** "Logos Kit isn't installed" [Get Logos Kit] [Use a passkey].
- **Failed:** shows the code, "Copy details" and [Retry].

---

## 6. Approval sheet (every transaction and message signature)

The sheet has three sections:
1. **Requested by:** same identity block as the ConnectSheet.
2. **What you're signing:**
   - program (name if known, otherwise "Unknown program"), program account (short, copyable), current `image_id` (short);
   - **verification badge**: ✓ Verified source (rebuilt locally) · ~ Claimed (not rebuilt) · ? Unknown · ✕ Mismatch;
   - **mutability**: "Immutable" or "Upgradeable by its owner";
   - raw instruction data behind a "Details" disclosure.
3. **What this means:**
   - decoded effects: "Send 12.5 LEZ from Public account 1 to 7Hk…9Qp";
   - **authority changes are highlighted in warning colour**: "Gives mint authority to …";
   - **Estimated fee**: "≤ 0.0021 LEZ" (or "Fee estimate unavailable");
   - visibility: "Visible on-chain: amount and both accounts" / "Private: nothing about this transfer is visible".

**Unknown effects:** a warning box, plus a required checkbox: "I understand Logos Kit can't describe what this does."

**Re-auth:** required for first connect, above the value threshold, and for private spends. The user enters the password.

**Buttons:** [Approve] arms after 500 ms · [Reject].

**After approval:** the sheet collapses into the tx row (§7), and the dApp gets a handle.

---

## 7. Transaction lifecycle and proving

**Row states** (Activity and toasts):
`Awaiting approval → Building → Proving (x%) → Signing → Submitted → Included → Confirmed | Failed | Not confirmed yet | Rejected | Expired`

- **Proving:**
  - named phases: Preparing → Generating proof → Submitting → Waiting for block;
  - an ETA from our measured benchmarks plus elapsed time: "about 4 min, 1:12 so far";
  - "This is normal for private transactions";
  - the bar eases toward 90% and never jumps backwards;
  - past the ETA: "Taking longer than usual…".
- **Minimise:** the modal collapses to a **pill** ("Proving… 42%") in the header or ConnectButton, and the user can keep working.
- **Survives restart:** status is kept by the engine. When the app reopens, the row resumes.
- **Cancel:** available only before submission.
- **Failure copy:** "Proof failed: the transaction wasn't sent. Nothing was spent." [Try again].
- **Outcome unknown:** "Included in block 26,110 but not confirmed. Logos Kit couldn't verify the result." [Check again].

---

## 8. Faucet mini-app

1. Pick an account (public or private).
2. [Get test funds].
3. Each step shows its own state:
   - **Claiming:** "Requesting from the faucet…"
   - **Rate limited:** "You can claim again in 3h 12m" (a live countdown).
   - **Outcome unknown:** "Checking whether funds arrived…", with a balance re-check.
   - **Funded:** "+150 LEZ to Public account 1".
   - **Private target:** "Moving funds into Private account 1" (the shield step, §7 proving).
4. **Done:** confirmed by the balance change, never by "queued" alone.

---

## 9. Testimonial mini-app

1. Connect, picking a **public** account (private accounts are disabled, with the tooltip "Testimonials are posted publicly").
2. Compose:
   - text (up to 280 characters, with a counter), prefilled with "I use Logos Kit wallet to …";
   - optional username (up to 32).
   - Validation: the text must mention "Logos Kit".
3. An activity nudge appears if the account has no prior activity: "Tip: fund your account and make a transfer first. Testimonials from active accounts carry more weight."
4. Approval → proving/submit → Posted: shows "Posted in block N", a copy explorer link, and [Open] via the core module.
5. One per account: "This account has already posted a testimonial."

---

## 10. Settings

- **Network:** the zone list, each zone's sequencer URL (editable), and a connection test.
- **Privacy:**
  - "Logos Kit makes no analytics or third-party calls."
  - Lists every network endpoint in use.
  - Optional services (all off by default), each with a description.
- **Security:** auto-lock timer, change password, reveal recovery phrase (needs the password).
- **Connected apps** (grants): each app with its accounts and capabilities, and [Revoke].
- **Backup:** encrypted backup to Logos Storage (optional) · Restore.

---

## 11. Error catalog (codes → copy)

| Code | Copy |
|---|---|
| 4001 | Request declined |
| 4100 | This app isn't connected to that account |
| 4900 | Wallet disconnected |
| 6101 | Couldn't simulate this transaction |
| 6102 | Proof failed: nothing was sent |
| 6103 | The sequencer rejected the transaction |
| 6106 | Something changed since you approved. Please review again |
| intent `cancelled` | You cancelled |
| intent `timeout` | The wallet didn't respond |
| intent `unavailable` | Logos Kit isn't available |
