# Parity ledger

The reference products are the **minimum baseline** (product-fidelity rule). Every capability below is marked with one of these statuses:

- **Exact:** same user-visible behaviour.
- **Adapted:** same promise, different implementation.
- **Additive:** new.
- **Blocked:** a named blocker prevents it.

Nothing is dropped silently. The "Stage" column is where the capability ships. Updated in each UI stage.

**Pinned sources**
- RainbowKit: `refs/connect-kits/evm/rainbowkit`
- ConnectKit: `refs/connect-kits/evm/connectkit`
- wagmi: `refs/connect-kits/evm/wagmi`
- Privy: `refs/connect-kits/embedded/*` and research notes 07
- Porto: `refs/connect-kits/passkeys/porto`
- Logos EVM signer stack: `refs/wallet-refs/logos-evm-*` (pattern only)

Research notes live in `../../../refs/connect-kits/_notes/`.

## Connection and modal (RainbowKit, ConnectKit)

| Capability | Reference | Status | Our version | Stage |
|---|---|---|---|---|
| Connect modal with wallet list | RainbowKit `ConnectModal` | Adapted | Web/RN: our modal lists the embedded passkey wallet, Wallet Standard discoveries and the Basecamp bridge. Basecamp: the shell's intent chooser *is* the wallet list | S11, S7 |
| Wallet groups: Recent / Installed / Recommended / More | RainbowKit `groupedWallets` | Exact | Recent / Detected / Recommended / More | S11 |
| Recent wallet first, persisted | RainbowKit `rk-recent` | Exact | `lk-recent` (web localStorage, RN AsyncStorage) | S11 |
| "Get a wallet" / install steps | RainbowKit `instructions.steps` | Adapted | "Get Logos Kit for Basecamp" (catalog URL, steps), "Use a passkey instead" | S11 |
| Connection states: connecting, expiring countdown, failed, rejected, request-already-pending, unavailable | ConnectKit `ConnectWithInjector` states | Exact | Same set. The Basecamp intent path maps shell errors: `cancelled` → rejected, `timeout` → expired, `unavailable` → unavailable | S11, S6 |
| Shake + "Try again" on failure | ConnectKit | Exact | Same, with `prefers-reduced-motion` honoured | S11 |
| 50 ms anti-flicker before showing "connecting" | RainbowKit `DesktopOptions` | Exact | Same | S11 |
| Spinner tracing around the wallet logo | RainbowKit mobile, thirdweb | Exact | 21st "Border Trail" (id 1135) around the real logo | S11 |
| Transport tabs (desktop / QR / deep link) | AppKit `w3m-connecting-header` | Adapted | [Basecamp] [Passkey] [Phone ↔ desktop pairing (S15)] | S11, S15 |
| Height morph between views | ConnectKit, AppKit ResizeObserver | Exact | ResizeObserver height animation | S11 |
| Bottom sheet on mobile widths | RainbowKit `bottomSheetOnMobile`, AppKit ≤430 px | Exact | Sheet below 640 px (web), native sheet on RN | S11, S14 |
| Account modal (balance, copy, disconnect, activity) | RainbowKit `AccountModal` | Exact | Plus a public/private badge and private-sync status | S11 |
| Chain modal / switch chain | RainbowKit `ChainModal` | Adapted | Network/zone modal: CAIP-2 zones with a per-zone sequencer. Becomes L1 ↔ zones in S17 | S11, S17 |
| `ConnectButton` plus a `.Custom` render prop | RainbowKit | Exact | `ConnectButton` + `ConnectButton.Custom` | S11 |
| Imperative modal hooks | RainbowKit `useConnectModal/useAccountModal/useChainModal` | Exact | `useConnectModal().open(): Promise<Account>` (the thirdweb promise form), `useAccountModal`, `useNetworkModal` | S11 |
| Themes (`light` / `dark` / `midnight`, accent, radius, font, overlay blur) | RainbowKit `ThemeVars` | Exact | `@logos-kit/theme` with the same knobs, plus status tokens; the same tokens drive QML and RN | S6, S11 |
| Scoped CSS vars, no global CSS leakage | RainbowKit `[data-rk]` | Exact | `[data-logos-kit]` plus the Tailwind `prefix(lk)`, no preflight | S11 |
| i18n with lazy locales | RainbowKit `locales/*` | Exact | `en` first; locale files are lazily imported | S11 |
| Recent transactions list and pending spinner ring | RainbowKit `useAddRecentTransaction`, `TxList` | Exact | A recent-tx store, plus the proving pill on the ConnectButton | S10, S11 |
| Sign-in (SIWE) step | RainbowKit `SignIn`, AppKit SIWX | Adapted | `lez_signIn` (BIP-340 over tag `LEZ/signin/v1`), states idle → creating → signing → verifying | S1, S10, S11 |
| App info / disclaimer slot | RainbowKit `appInfo.disclaimer` | Exact | Same | S11 |
| Cool mode | RainbowKit `coolMode` | Exact (opt-in) | Same | S11 |
| a11y: focus trap, aria, ESC, reduced motion | RainbowKit `Dialog`, Radix | Exact | Radix-based dialog from 21st (ids 376/1248) | S11 |
| SSR safety (mounted flag, cookie state) | wagmi `cookieToInitialState`, RainbowKit `mounted` | Exact | Same | S10, S11 |

## SDK and hooks (wagmi, viem)

| Capability | Reference | Status | Our version | Stage |
|---|---|---|---|---|
| Framework-free core: store, connectors, actions | `@wagmi/core` | Exact | `@logos-kit/core` | S10 |
| TanStack query options and query keys | `@wagmi/core/query` | Exact | Keys `['lez', action, params]` | S10 |
| Hooks of about 10 lines each | `wagmi` | Exact | `@logos-kit/react` | S10 |
| Multi-connection store | wagmi `connections` Map | Exact | Same | S10 |
| Silent reconnect order | wagmi `reconnect` | Exact | Same; the passkey never prompts on load | S10 |
| Mock connector with failure flags | wagmi `mock` | Exact | `@logos-kit/test` | S10 |
| Typed error classes (`shortMessage`, `docsPath`, `walk`) | viem `BaseError` | Exact | `@logos-kit/protocol` | S1 |
| Client + transports + `.extend()` | viem | Exact | `@logos-kit/client` | S6 |
| Wallet discovery | EIP-6963 / Wallet Standard | Adapted | Wallet Standard plus a reverse-DNS `info.id`. Basecamp discovery happens through the intent chooser | S10, S12 |
| Capabilities | EIP-5792 | Adapted | `lez_getCapabilities`, returned in the connect result | S1 |
| Tx status (`wallet_getCallsStatus`) | EIP-5792 | Adapted | `lifecycle` + `outcome`. LEZ has no receipts, so `outcome` comes only from events or own-account invariants | S1, S3 |
| CLI codegen from ABI | `@wagmi/cli` | Additive (later) | IDL → typed hooks | after S16 |

## Embedded wallet (Privy, Porto)

| Capability | Reference | Status | Our version | Stage |
|---|---|---|---|---|
| Create-on-connect | Privy `createOnLogin` | Exact | Passkey create during connect | S12 |
| Confirmation modal with per-call copy (`uiOptions`) | Privy | Exact | `ConfirmSheet` plus per-call `ui` overrides | S11, S12 |
| Headless mode (no UI) | Privy `showWalletUIs:false` | Exact | `ui={false}` | S11 |
| Key export | Privy (web only) | Exact+ | Mnemonic export on every surface | S12, S14 |
| Account centre | Privy `UserObject` | Exact | `AccountCenter` | S12 |
| Step-up above a threshold | Dynamic | Exact | Re-auth above a value threshold | S3, S12 |
| Dialog/popup origin isolation | Porto `Dialog`, `Messenger` | Exact | Wallet origin, iframe + popup, MessageChannel | S12 |
| App ID / dashboard | Privy/Dynamic dashboard | Adapted | **No dashboard.** Every setting is in `createConfig()` or files the CLI generates | S12, S13 |
| Hosted key custody (TEE/MPC) | Privy, Para, Turnkey | Blocked (by design) | Keys never leave the user's devices. Prize rule plus our privacy stance | — |

## Approval flow (Logos EVM signer stack, pattern only)

| Capability | Reference | Status | Our version | Stage |
|---|---|---|---|---|
| Requester can ask, only the approver can approve | `logos-evm-keystore-module` roles | Exact | Core-owned pending requests; only `WalletUi` approves | S3, S7 |
| Echoed bundle id and a password per approval | EVM keystore | Adapted | Echoed canonical request hash; re-auth for first connect, above a threshold, and for private spends | S3 |
| Human-readable decode with confidence tiers | `logos-tx-decoder` | Adapted | Wire-byte decoders: `Summary{…, unknown}`, authority-change flags | S4 |

## Logos-specific (additive)

| Capability | Status | Stage |
|---|---|---|
| Public/private account picker; "Syncing… (height N)" instead of a fake 0 | Additive | S7, S11 |
| Proving progress (phases, ETA from benchmarks, minimise to a pill, survives reload) | Additive | S3, S7, S11 |
| Program source-verification badge (verified locally / claimed / unknown / mismatch, plus mutability) | Additive | S4, S7 |
| In-flow faucet (`lez_requestFunds`) | Additive | S1, S8 |
| Testimonial client on all three surfaces (D2) | Additive | S8, S13, S14 |
| Private receive codes, payment requests, fingerprints | Additive | S7, S15 |
| Paired home prover for web/mobile private spends | Additive | S15 |
