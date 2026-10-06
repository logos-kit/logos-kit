# Token UX research notes (working file, 2026-10-06)

## 1. MetaMask

### Detection (VERIFIED, support doc https://support.metamask.io/manage-crypto/tokens/how-to-display-tokens-in-metamask/)
- Auto-displays popular ERC-20 + SPL tokens. Two ways for "unlisted" tokens to appear: Enhanced token detection (default on for EVM + Solana) or manual add by search/address (EVM, Solana, Tron).
- Enhanced detection networks: Ethereum, Linea, Avalanche, BNB, Polygon, Arbitrum, Optimism, Base, zkSync, Solana, Arc.
- Gated by "Basic Functionality" (Settings > Privacy). Mainnet detection happens regardless; Basic Functionality expands to other networks.
- "uses lists of tokens aggregated from various community token lists; MetaMask doesn't keep a proprietary list of 'accepted' or 'valid' tokens."
- Manual add: Manage tokens -> list with toggles + search by name/symbol + network filter -> "Add custom token" -> paste contract address -> Next -> Import. Mobile: '+' -> search -> 'Custom token' tab.
- Explorer/CoinGecko/CMC "Add to MetaMask" buttons (wallet_watchAsset) -> confirmation prompt.
- Hide: Manage tokens toggle, or token page ... > Hide; mobile long-press. Native gas token cannot be hidden.
- https://support.metamask.io/manage-crypto/tokens/how-to-remove-a-token/ : hiding does not change on-chain balance nor revoke allowances.
- Default-on for new extension users since July 11 2024 (https://metamask.io/news/metamask-ui-update-token-auto-detection); existing users got a modal prompting opt-in.

### Detection internals (VERIFIED, source MetaMask/core packages/assets-controllers @ dc8658bd, 2026-10-06)
- token-service.ts: TOKEN_END_POINT_API = https://token.api.cx.metamask.io ; list fetched from /tokens/{chainId}?occurrenceFloor=N ; N from /v1/suggestedOccurrenceFloors, DEFAULT_OCCURRENCE_FLOOR = 3 (a token must appear on >= N aggregator lists). Linea: lineaTeam aggregator OR >=3 aggregators.
- TokenDetectionController.ts: DEFAULT_INTERVAL 180000 ms (3 min). For chains in SUPPORTED_NETWORKS_ACCOUNTS_API_V4 (mainnet, Polygon, BSC, Linea, Base, OP, Arbitrum, Scroll, Sei, Monad, HyperEVM, Arc, Robinhood) balances come from Accounts API (https://accounts.api.cx.metamask.io) + websocket; other chains: RPC -- take token-list addresses not already in allTokens/allDetectedTokens/allIgnoredTokens, slices of 1000, single-call balance check, add those with nonzero balance.
- CRITICAL: both RPC and websocket paths `continue` (skip) any held token whose address is NOT in the token-list map. So on EVM, an arbitrary airdropped ERC-20 that's not on >=3 lists is NOT auto-shown; user must import by address. This is MetaMask's built-in spam filter.
- If detection disabled: mainnet falls back to static legacy list (@metamask/contract-metadata).
- Icons: https://static.cx.metamask.io/api/v1/tokenIcons/{chainIdDecimal}/{address}.png (assetsUtil.ts formatIconUrlWithProxy) -- proxied, not hotlinked from token-chosen URLs.
- TokenListController DEFAULT_INTERVAL = 4h.
- Ignored (hidden) tokens are excluded from re-detection (allIgnoredTokens).
- Solana/multichain (MultichainAssetsController.ts): SPL tokens held are auto-added BUT filtered by Blockaid bulk token scan (batch 100) -- rejects only definitive `Malicious`, fail-open on API error; re-scans stored SPL tokens daily (DEFAULT_BLOCKAID_TOKEN_RESCAN_INTERVAL_MS = 24h) and auto-ignores ones newly flagged malicious.

### Strings (VERIFIED, metamask-extension app/_locales/en/messages.json)
- customTokenWarningInTokenDetectionNetwork: "Anyone can create a token, including creating fake versions of existing tokens. Learn about $1"
- useTokenDetectionPrivacyDesc: auto-display "involves communication with third party servers to fetch token's images. Those serves will have access to your IP address."
- personalAddressDetected: "Personal address detected. Input the token contract address."
- tokenDecimalsMustBeWholeNumber (0..36); symbolBetweenZeroTwelve ("11 characters or fewer"); tokenAlreadyAdded
- hideZeroBalanceTokens "Hide tokens without balance"; lowValueAssets "Low balance tokens ($1)"; sortByAlphabetically / sortByDecliningBalance; searchTokensByNameOrAddress
- securityTrustFeatureImpersonator* (Likely/Possible/Unconfirmed impersonator, Impersonates a sensitive asset); confusableUnicode "'$1' is similar to '$2'."
- addressCopied "Address copied"; tokenDetails; tokenStandard

### Privacy (VERIFIED https://support.metamask.io/configure/privacy/how-to-adjust-metamask-privacy-settings/)
- 'Basic Functionality' single toggle covers token detection, balance/price checker, NFT detection, tx simulations, security alerts, etc.; IP shared with MetaMask; cannot disable individually; social-login users can't disable.

### NFTs (VERIFIED https://support.metamask.io/manage-crypto/nfts/nft-tokens-in-your-metamask-wallet/)
- NFT autodetect on Ethereum, Base, Linea, SEI, Monad, Avalanche; part of Basic Functionality.
- Import NFT: network + contract address + Token ID. ERC-721 & 1155 viewable; sending only ERC-721. Errors: "not the owner", "Personal address detected."

### Safety (VERIFIED https://support.metamask.io/stay-safe/safety-in-web3/token-safety-practices/)
- "Anyone can mint a token and name it any way they like" ; airdrop scams reroute to sites asking for SRP; "If you do have scam tokens airdropped to your account, just leave them there".

## 2. Phantom (closest analog)

### Discovery & metadata (VERIFIED https://docs.phantom.com/best-practices/tokens/token-display)
- "If Phantom users own a certain balance of a token made with these programs [SPL Token / Token-2022], that balance will always appear in their wallet. However, if Phantom cannot find more metadata about that token, it will display the token as 'Unknown.'" -> i.e. ownership-driven discovery, not allowlist-driven (contrast MetaMask EVM).
- Metadata resolution order: Metaplex Token Metadata account first; on-chain fields (name, symbol) prioritized over off-chain JSON at `uri`.
- Fallback (https://docs.phantom.com/best-practices/tokens/home-tab-fungibles): deprecated Solana Labs Token List (name, symbol, logoURI, coingeckoId). Prices: CoinGecko (verified contract = mint), fallback Birdeye.
- Categorization by Metaplex `tokenStandard` (Fungible -> Home tab; FungibleAsset/NonFungible/NonFungibleEdition/ProgrammableNonFungible -> Collectibles tab). Fallback heuristic if no tokenStandard: supply == 1 -> NonFungible; supply > 1 && decimals == 0 -> FungibleAsset; else Fungible.
- Visibility: "Tokens that do not meet certain signals may be hidden or shown with a warning indicator" ; signals from internal systems + third parties incl. Blockaid; criteria deliberately unpublished; devs told to get listed on CoinGecko and Jupiter; appeal via Blockaid portal.

### Spam / hidden (VERIFIED)
- https://help.phantom.com/hc/en-us/articles/42969287602963 : "Phantom automatically hides tokens that look like spam"; restore via Tokens -> sliders icon (mobile) / ... -> Manage Tokens (extension) -> toggle on. "Restoring a token only makes it visible in your wallet. It does not mean the token is safe or verified." Manual hide via same toggles.
- https://help.phantom.com/articles/why-is-my-token-hidden-or-flagged-as-spam-51665009279251 : flagged tokens "may appear with a warning, move to your hidden token list, or be removed from view entirely"; if not in hidden list it may be fully filtered and cannot be unhidden; verified tokens show "a purple checkmark"; unverified show "This token is unverified. Only interact with tokens you trust."; unverified "is not automatically a scam"; "Detection re-runs automatically and regularly".
- Report: https://help.phantom.com/hc/en-us/articles/38409446731539 : extension token page More > Report as Spam; mobile View > ... > Report; same for collectibles. "anyone can send tokens or collectibles to your wallet without your permission"; receiving does not mean compromise; "Don't follow links or instructions associated with it."
- https://help.phantom.com/articles/tokens-or-collectibles-i-received-arent-showing-in-phantom-28975264693267 : checklist (address/network, explorer, hidden list, sender).
- Token toggles introduced v0.10.0: hide tokens with balances, show tokens without balances (https://x.com/phantom/status/1427669854274736140) [VERIFIED official X post title].
- https://phantom.com/learn/crypto-101/common-crypto-scams : copycat tokens "use the same name, icon, and symbol as the real token with slight changes"; Phantom auto-detects/hides fungible tokens with URLs in names; security metrics (holder distribution, mutability); warnings when buying copycats; warnings when copying unverified addresses from history (address poisoning); airdrop red-flag words Free/Gift/Limited/Airdrop/Giveaway/Congrats.
- Frozen tokens (https://help.phantom.com/articles/what-are-frozen-tokens-on-solana-29763090277139): freeze authority scam pattern; Phantom can't unfreeze.

### NFTs (VERIFIED https://docs.phantom.com/best-practices/tokens/collectibles-nfts-and-semi-fungibles)
- Group by verified collection mint, fallback first verified creator; naming priority list; media priority animation_url > properties.files (cdn:true first) > image; resize to 256x256.
- Burn NFTs (Aug 17 2022, https://phantom.com/learn/blog/introducing-burn-nfts): Collectibles -> ... -> Burn Token; returns rent SOL; blocklist of 800+ malicious collection addresses hides items; report spam -> Hidden folder (https://phantom.com/learn/blog/security-at-phantom).
- Close empty fungible token accounts: no first-party evidence Phantom exposes it; third-party tools (Sol Incinerator) used (INFERRED from https://solanacompass.com/tools/solana-token-account-rent-reclaim, not official).

### Asset page (VERIFIED https://help.phantom.com/articles/understanding-asset-pages-in-phantom-52633747656211)
- Aggregated asset across variants/networks; "Your Positions"; position detail: price chart, value, return, balance, cost basis, realized P&L; actions Trade / Send / Receive / Share / switch variant.

## 2b. Solana primitives that wallets build on
- getTokenAccountsByOwner (VERIFIED https://solana.com/docs/rpc/http/gettokenaccountsbyowner): "Returns SPL Token accounts whose owner matches the supplied address"; requires filter `mint` OR `programId`; jsonParsed gives mint, owner, tokenAmount, delegate, state, isNative. Wallets call it twice (Token + Token-2022 program ids) to enumerate everything -> any token sent to you shows.
- ATA (VERIFIED https://solana.com/docs/tokens/basics/create-token-account): seeds owner + token program + mint under ATA program; "exactly one ATA address"; rent ~0.00203928 SOL (Token) / ~0.00207408 (Token-2022), refundable when closing an empty account; query getMinimumBalanceForRentExemption dynamically.
- Helius DAS getAssetsByOwner (VERIFIED https://www.helius.dev/docs/api-reference/das/getassetsbyowner): one call for NFTs + cNFTs + fungibles; options showFungible, showNativeBalance, showZeroBalance, showUnverifiedCollections, showCollectionMetadata; `interface` enum FungibleToken / FungibleAsset / V1_NFT / ProgrammableNFT / MplCoreAsset ...
- Metaplex Token Metadata (VERIFIED https://metaplex.com/docs/token-metadata): metadata PDA derived from mint; on-chain name, symbol, uri, creators (verified flag), collection, tokenStandard (auto-computed), isMutable, updateAuthority; off-chain JSON at uri.
- Token-2022 metadata (VERIFIED https://solana.com/docs/tokens/extensions/metadata): MetadataPointer + TokenMetadata on the mint itself (name, symbol, uri, update_authority, additional_metadata).
- Deprecated solana-labs/token-list (VERIFIED https://github.com/solana-labs/token-list/blob/main/README.md): archived (June/July 2022), use Metaplex fungible token metadata instead; npm @solana/spl-token-registry left.
- Jupiter Tokens API v2 (VERIFIED https://developers.jup.ag/docs/tokens/v2): search by symbol/name/mint (<=100 mints), tag (verified, lst, stocks), category (toporganicscore/toptraded/toptrending), recent. Fields id, name, symbol, icon, decimals, isVerified, tags, organicScore, holderCount, mcap, liquidity, audit{mintAuthorityDisabled, freezeAuthorityDisabled, topHoldersPercentage}.
- LIVE CHECK (VERIFIED, curl https://lite-api.jup.ag/tokens/v2/search?query=USDC on 2026-10-06): real USDC EPjFWdd5... isVerified=true, tags [verified, stable, community, strict], organicScore 100; results also include >=7 tokens whose SYMBOL is literally "USDC" ("USD//COIN", "Unites States Dollar Coin", "USDC Upside Down Cat", "The USDC Drainer" w/ symbol DRAINER) all tags ['unknown'], organicScore 0. => symbol/name are NOT identity.
- Jupiter verification (VERIFIED https://docs.jup.ag/user-docs/launch/vrfd/token-verification): green check = "canonical version"; "Verification is not an endorsement"; criteria organic score, mcap, holders, liquidity, ticker uniqueness, social support; revocable on ticker conflict / liquidity loss. Old jup-ag/token-list archived; strict list used by partners (search result summary; https://github.com/jup-ag/token-list).

## 2c. LEZ token model (VERIFIED from local source refs/lez/lez-programs @494dba8, 2026-09-25; refs/lez/logos-execution-zone @f7fda38)
- programs/token/core/src/lib.rs: TokenDefinition::Fungible { name, total_supply: u128, metadata_id: Option<AccountId>, authority: Option<AccountId> } ; NonFungible { name, printable_supply, metadata_id }.
  -> NO symbol and NO decimals on chain. apps/token/qml/pages/CreatePage.qml: "Raw u128 value. Display decimals are inferred by clients, not stored here."
- TokenHolding::Fungible { definition_id, balance: u128 } | NftMaster { definition_id, print_balance } | NftPrintedCopy { definition_id, owned }. NO owner field in holding data (ownership = account authorization / PDA seed).
- TokenMetadata { definition_id, standard: Simple|Expanded, uri, creators: String, primary_sale_date } -- off-chain JSON pointer, like Metaplex uri.
- ATA program (programs/ata/core/src/lib.rs): seed = sha256(token_program_id || owner || definition_id); id = AccountId::for_public_pda(ata_program_id, seed). Create is idempotent and src/create.rs says "No explicit owner authorization check is needed here" -> INFERRED: a third party can create your ATA and Transfer into it (Transfer requires recipient holding initialized) => unsolicited/airdrop spam is possible for public accounts, exactly like Solana.
- No getTokenAccountsByOwner equivalent. Indexer RPC (lez/indexer/service/rpc/src/lib.rs): getAccount, getAccountSummary, getTransactionsByAccount(account, offset, limit), getEvents(filter), subscribeToEvents, subscribeToFinalizedBlocks. Sequencer RPC: getAccount, getAccountBalance, getAccountsNonces, sendTransaction...
  -> INFERRED discovery strategy: (a) derive ATA for every definition in a registry + user's custom list and batch getAccount; (b) scan getTransactionsByAccount(owner) -- ATA Create lists the owner as a required account, so third-party ATA creations surface in the owner's history -> decode definition ids -> derive & fetch; (c) subscribeToEvents for live updates. Non-ATA holdings (random keypair holdings) only discoverable via history.
- Existing registry shape (apps/amm/amm-tokens.json.example, artifacts/amm-registry.testnet.json): { network, symbol, name, definitionId, decimals? } ; RegistryLoader.cpp: "decimals is optional ... absent => 0".

## 3a. Rabby (VERIFIED from source RabbyHub/Rabby @7794bfb 2026-09-30; https://github.com/RabbyHub/Rabby)
- Data: DeBank-backed openapi.listToken(user, chain, isAll) per used chain (src/ui/utils/portfolio/tokenUtils.ts batchQueryTokens). Server indexes every token the address holds; classification flags come from server: is_core, is_verified, is_suspicious, protocol_id.
- src/ui/utils/portfolio/lpToken.ts: commonTokenFilter drops is_verified === false (comment: null = not processed, false = explicitly confirmed scam) or is_suspicious; defaultTokenFilter also drops is_core === false and non-core protocol tokens; isUnknownToken = is_core null && not LP. => three-state trust (core / unknown / scam).
- Low-value folding: src/ui/utils/portfolio/expandList.ts: threshold = min(total/100, 1000) USD (1% of portfolio, capped $1000); fold only when list >=3 and >=4 items below threshold; totalValue counts only is_core tokens (TokenList.tsx). Folded row "{{count}} low-value tokens"; "Low value assets will be shown here".
- Sorting (tokenUtils.ts concatAndSort): core first, then USD value desc.
- Lists: customizedToken (user-added) and blocked tokens (user-blocked) persisted in background/service/preference.ts. Strings (_raw/locales/en/messages.json): "Add custom token", "Custom token added by you will be shown here", "Token blocked by you will be shown here", "Blocked token will not be shown in token list", "Token is not listed by Rabby. It will be added to the token list if you switch on.", "The token is not listed by Rabby. You've added it to the token list manually."
- Scam warnings: tokenDetail.verifyScamTips "This is a scam token"; maybeScamTips "This is a low-quality token and may be a scam"; signTx.fakeTokenAlert "This is a scam token marked by Rabby"; history label "Scam tx".
- Add custom token: "Token address on multiple chains. Please choose one", "Token not found from this contract address", "Token has been supported on Rabby", shows Balance before adding.
- Token detail fields: Token Name, Chain, Contract Address, My Balance, issuance ("Bridged token by a third party" / "Natively issued on this blockchain"), Bridge Provider, Issuer's Website, Original Token, Listed by, Supported Exchanges, FDV tooltip; actions Swap / Send / Receive / Bridge; "No Transactions".
- Token selector: "Search by Name / Address", sections Hot / Common / Recent, "Try to search contract address on {{chainName}}" when no match.
- Send: MAX, "Gas fee reservation required", Reserve Gas toggle, contacts ("Not on address list. Add to contacts"), whitelist mode, OFAC blocked-address modal.
- Desktop: "Hide $0 tokens".

## 3b. Rainbow (VERIFIED source rainbow-me/rainbow @a64ecce 2026-10-05 + help docs)
- Backend "addys" (Rainbow address indexer) returns every asset; src/resources/addys/types.ts: `probable_spam: boolean` with comment "To avoid zerion from filtering assets themselves, we add this internal flag to verify them ourselves"; `verified?: boolean` "For ERC-20 tokens, we show the verified status".
- src/state/assets/createUserAssetsStore.ts: hiddenAssets Set<UniqueId> keyed by address+chainId; hiddenAssetsBalance computed separately (hidden value tracked, not lost).
- en_US.json strings: wallet.action Pin / Unpin / Hide; expanded_state.asset.menu Pin/Unpin/Hide; token_search sections "Verified" / "Unverified"; exchange token sections Verified/Unverified; NFT "Showcase" / "Hide".
- https://rainbow.me/support/app/hide-and-unhide-tokens : tap All -> Edit -> select -> Hide/Unhide; "built-in spam filter that automatically hides tokens that we detect are spammy"; hidden spam remains reviewable in hidden list; "Never go to a website listed in a token's name".
- https://rainbow.me/support/extension/hide-and-unhide-tokens-on-the-browser-extension : right-click -> Hide; "H" keyboard shortcut; cmd/ctrl+K command palette search incl. hidden tokens.

## 3c. Backpack (VERIFIED source coral-xyz/backpack public repo @5a538a4, Feb 2024 -- stale snapshot, current app closed)
- "Manage token display" drawer listing owned tokens with Switch per token; i18n hidden_tokens_description "Disable a token in this list to hide it from your wallet balances table."; hidden token addresses per blockchain (UI_RPC_METHOD_HIDDEN_TOKENS_UPDATE).
- Collectibles: unverified collections hidden by default with "Show All" / "Hide Some" toggle (ShowUnverifiedToggle.tsx).
- Fallbacks: UNKNOWN_ICON_SRC (grey circled "?" SVG) for missing token logos, UNKNOWN_NFT_ICON_SRC for broken NFT media; label "Unknown Token" (packages/common/src/constants.ts, i18n en.json).

## 3d. Solflare (VERIFIED https://www.solflare.com/crypto-101/crypto-wallet-security-101-how-solflare-protects-your-assets/)
- "Verified tokens come with trusted data — real name, symbol, icon, and contract address" vs "Unverified tokens may be missing information, or could be copycats"; users can still interact but are notified.
- Spam NFTs: "placed in a dedicated 'Unverified' folder — hidden from your main gallery, but still visible"; actions: Burn / Ignore (leave in Unverified) / move to verified collection; burning flags the contract for the community.
- (search-summary, not read on official page; treat INFERRED): unverified reasons incl. minted <24h, not on Jupiter verification, low liquidity/holders; hiding is local-only, account still holds ~0.00204 SOL rent.
- Frozen token help: https://help.solflare.com/en/articles/9582028-the-token-i-bought-is-frozen-what-can-i-do

## 3e. Coinbase Wallet / Base app (VERIFIED)
- https://help.coinbase.com/en/wallet/security/fake-stablecoins (via Firecrawl): genuine USDC/USDT "will always display the exact dollar amount" + official logo with chain badge (ETH symbol lower-right); "If the token does not display a dollar amount or has a different logo, it may be a fake token." Hide: Settings -> Display -> Hide assets -> enter asset name; "This action is safe and does not require interaction with the underlying contract." Airdrop claim requires connecting to a contract = high-risk.
- https://www.coinbase.com/blog/detecting-the-undetectable-coinbase-erc-20-scam-token-detection-system (Oct 6 2023): smart-contract auditing via simulation (honeypots, internal fees) + ML anomaly detection on tx patterns, retrained daily; produces a whitelist of trusted tokens; Wallet hides scam/spam tokens -> ~2x spam filtering.
- Token page ... -> "Hide & report" (https://x.com/CoinbaseSupport/status/1969967423227900407, official support account).

## 4. Token lists & logo sources
- Uniswap Token Lists (VERIFIED local clone Uniswap/token-lists @01705f9, src/tokenlist.schema.json; https://github.com/Uniswap/token-lists):
  - TokenInfo required: chainId (int>=1), address (pattern now ^(0x[a-fA-F0-9]{40}|[1-9A-HJ-NP-Za-km-z]{32,44})$ i.e. EVM OR base58), decimals (0..255), name (<=60), symbol (<=20); optional logoURI ("suggest SVG or PNG of size 64x64"; "if not set, interface will attempt to find a logo based on the token address"), tags (ids defined at list level), extensions.
  - List root required: name, timestamp, version{major,minor,patch}, tokens (1..10000); optional tokenMap, keywords (<=20), tags (<=20 defs, name <=20 chars), logoURI (256x256).
  - Semver rules: major when tokens removed or addresses changed; minor when tokens added; patch for anything else.
  - Schema id https://uniswap.org/tokenlist.schema.json; files *.tokenlist.json auto-validated in editors; validate with ajv.
- Trust Wallet assets (VERIFIED https://raw.githubusercontent.com/trustwallet/assets/master/README.md + https://developer.trustwallet.com/developer/new-asset/requirements.md):
  - path blockchains/<chain>/assets/<address>/logo.png + info.json; logo PNG 256x256, transparent preferred, lowercase extensions.
  - info.json: name, type (ERC20/SPL...), symbol, decimals, description, website, explorer, status (active ...), id, links[], tags[].
  - "brand new tokens are not accepted"; min 10,000 holders & 15,000 tx (airdropped tokens excluded); copies of USDT/USDC/DAI branding rejected; non-refundable fee; "mass distribution of tokens to random addresses will result in the asset being flagged as spam".
  - Data-quality observation (VERIFIED by fetching blockchains/solana/assets/EPjF.../info.json): Solana USDC entry's links point to t.me/stakingfacilities and x.com/solanabeach_io -> community metadata can be wrong; don't treat registry links as authoritative.
- Uniswap token warnings (VERIFIED source Uniswap/interface @95fccc9 packages/uniswap/src/features/tokens/warnings/safetyUtils.ts; https://support.uniswap.org/hc/en-us/articles/8723118437133-What-are-token-warnings ; https://blog.uniswap.org/new-token-warnings):
  - Priority ladder: Blocked (on blocked list) -> MaliciousHoneypot (FOT == 100%) -> FotVeryHigh (>=80% or malicious/spam + HighFees) -> MaliciousImpersonator (malicious/spam + Impersonator) -> FotHigh (>=15%) -> MaliciousGeneral -> PotentialHoneypot -> ExitScamRisk -> SpamAirdrop (spam + Airdrop) -> FotLow (>0) -> NonDefault (not on default token list) -> None.
  - Severity: Blocked; High = honeypot/impersonator/malicious/FOT>=15; Medium = potential honeypot/exit-scam/spam-airdrop/FOT low; Low = NonDefault; None. Natives always None.
  - Data from Blockaid ("dynamic and static heuristics, AI, and machine learning models"); "Uniswap Labs is not able to adjust warnings on specific tokens"; appeals to report.blockaid.io.
- Logo fallback, Rainbow (VERIFIED src/utils/CoinIcons/FallbackIcon.js, components/coin-icon/RainbowCoinIcon.tsx, FastFallbackCoinIconImage.tsx): if icon missing OR image load errors -> colored circle (token's palette color or theme default) with white uppercase symbol, symbol sanitized `replace(/[^a-zA-Z0-9]/g,'')`, max 5 chars (1 char under 30px), font size by length; images loaded through ImgixImage proxy; chain badge (ChainImage) overlaid on the coin icon.
- Logo proxying: MetaMask static.cx.metamask.io/api/v1/tokenIcons/{chain}/{address}.png (keyed by address, not by token-supplied URL); MetaMask privacy string warns image fetch exposes IP to third-party servers.

## 3f. Family (VERIFIED help center https://family.co/support + design essay)
- Sort tokens: Highest Value (default), Market Cap, Alphabetically, Custom (drag & drop in Manage Tokens), Starred (https://family.co/support/sort-tokens-and-collectibles). Collectibles: Most Recent (default) / Starred; Gallery mode.
- Star: swipe left on token row -> star; long-press NFT -> star (https://family.co/support/star-tokens-and-collectibles).
- Hide (Manage Tokens -> select -> Hide; reversible) vs Trash ("move these tokens out of your main wallet view, into a separate Trash section") + global "Auto-trash spam" setting (https://family.co/support/hide-tokens-and-collectibles, https://family.co/support/trash-tokens-and-collectibles).
- "Refresh metadata on collectible" support article exists (https://family.co/support).
- Design (https://benji.org/family-values): items tumble into skeuomorphic trash can with sound; drag-reorder with stacking animation; chart scrubbing with flipping arrows; stealth mode (hide balances) with shimmer.

## 5. Address poisoning (VERIFIED)
- https://support.metamask.io/stay-safe/protect-yourself/wallet-and-hardware/address-poisoning-scams/ : scammer sends negligible/zero-value transfer from vanity lookalike; MetaMask compares destination vs history -> blocking warning when first 4 + last 4 match but middle differs; warning for never-interacted addresses; advise address book.
- https://metamask.io/news/address-poisoning-detection (June 17 2026): live on Mobile + Extension across EVM; "speed bump ... then lets you decide"; first-time-send warning; addresses now shown longer (0xEdf89FdA047F28…C6341a8ff7ED instead of 0xEdf89…ff7ED); Blockaid flagged 65.4M poisoning txs Jan 2025-Feb 2026.
- Phantom: warns when copying unverified addresses from history (https://phantom.com/learn/crypto-101/common-crypto-scams). Press (INFERRED, not official): Phantom chat $264K loss via poisoning (https://cointelegraph.com/news/phantom-chat-address-poisoning-bitcoin-phishing); Ledger Live hides zero-value token transfers by default; Trust Wallet poisoning protection across 32 EVM chains Mar 2026 (search summary, unverified).

## 6. Token detail screen -- MetaMask extension (VERIFIED source MetaMask/metamask-extension @a6765b1 2026-10-02: ui/pages/asset/components/asset-page.tsx, token-asset.tsx; strings app/_locales/en/messages.json)
- Order: header (balance, price chart, Buy/Swap/Send/Receive) -> "Your balance" -> AssetPageSecurityTrustSection ("Security and trust") -> "Token details": Network (network avatar + name), Contract address (AddressCopyButton, shortened, copy), Token decimal, "Token lists" (aggregator names, e.g. which lists include it), "Spending caps" -> Edit in Portfolio -> market details -> "Your activity" (ActivityList filtered by CAIP asset id).
- Options menu (token-asset.tsx): "View on block explorer" (token tracker URL), Hide -> HideTokenConfirmationModal ("Hide token?" / "Hide $1").
- Security & trust tiers: Verified ("$1 is actively traded and is widely recognized. Verification is not an endorsement by MetaMask.") / No issues ("No risk signals detected. Always research any asset before trading.") / Suspicious ("Security partners found risk signals in this token's contract or trading activity.") / Malicious ("Security partners flag this token as high risk.") / Unavailable ("Security analysis could not be loaded for this token.") + "Continue anyway"; info rows Token age, Token distribution, Top 10 holders, Total supply, Official Links (Website, Telegram, Etherscan); feature chips e.g. Mintable, Honeypot risk, Impersonator (Likely/Possible/Unconfirmed), Suspicious airdrop, Spam text, Concentrated supply, Transfers pauseable, Owner can change balance, Hidden owner, Established reputation, Listed on exchange; disclaimer "This security review is for evaluation only and does not constitute an endorsement".
- MetaMask low-value bucket (VERIFIED ui/components/app/assets/hooks/useLowValueTokenPartition.ts @a6765b1): threshold $1 converted to display currency; bucket if priced < threshold OR UNPRICED while any other token is priced; native + mUSD never bucketed; skipped when Basic Functionality off; collapsed row "Low balance tokens ($1)"; expand state remembered per session (token-list.tsx).
- MetaMask addToken (VERIFIED TokensController.ts): adding a token removes it from allIgnoredTokens and allDetectedTokens (re-import = unhide); fetches aggregators from token API; image defaults to proxied icon URL; per chain per account state (allTokens / allDetectedTokens / allIgnoredTokens).
- MetaMask airdrop doc (VERIFIED https://support.metamask.io/stay-safe/protect-yourself/tokens-and-transactions/how-to-tell-the-difference-between-a-regular-airdrop-and-airdrop-phishing-scams/): "no one can get access to your funds ... simply by depositing tokens into your wallet"; "MetaMask does not automatically display all tokens, but only established ones"; "MetaMask's token detection only displays tokens on approved, curated lists"; scam = failed swap error text on explorer pointing to phishing site.
- MetaMask Portfolio NFTs (VERIFIED https://support.metamask.io/manage-crypto/nfts/an-nft-is-missing-marked-suspicious-or-not-displaying-correctly-in-metamask-portfolio/): auto-marks NFTs 'suspicious' from data providers -> separate suspicious tab; user can mark "not suspicious"; airdropped NFTs embed URLs in image/About text; unsupported media -> placeholder.
- CoinGecko token list (VERIFIED live curl https://tokens.coingecko.com/solana/all.json 2026-10-06): Uniswap token-list format, name "CoinGecko", version {801,10,0}, 7315 Solana tokens, logoURI on assets.coingecko.com (thumb); chainId null for Solana (non-EVM deviation). Also /uniswap/all.json (Ethereum).
- Phantom send (VERIFIED https://help.phantom.com/hc/en-us/articles/5530158379539-Send-crypto-from-Phantom): paste address / username / QR; network badge on token icon; "Phantom may warn about new addresses"; format mismatch error; "Phantom blocks certain scam tokens designed to prevent sending or selling". Fee shortfall: "Not Enough SOL" (https://help.phantom.com/hc/en-us/articles/30698882147859).
- Phantom privacy mode: long-press balance to hide (https://x.com/phantom/status/1569732862978715648, official account).
- LEZ indexer indexes affected PUBLIC accounts only (VERIFIED lez/storage/src/indexer/write_atomic.rs uses tx.affected_public_account_ids(); lee/state_machine/src/public_transaction/transaction.rs = signers + all message.shard_selectors account ids; privacy-preserving tx = signers + public_actions ids). => getTransactionsByAccount(owner) returns any public tx that lists the owner account, incl. a third party's ATA Create (owner is a required account). Private holdings are NOT discoverable via indexer (INFERRED: must be tracked locally by the wallet).
- Confusables standard (VERIFIED https://www.unicode.org/reports/tr39/): "X and Y are defined to be confusable if and only if skeleton(X) = skeleton(Y)"; whole-script confusables e.g. Latin "scope" vs Cyrillic.

==========================================================================================
# SYNTHESIS
==========================================================================================

## (a) Comparison table  (V = verified on official doc/source, I = inferred / third-party summary)

| Wallet | How held tokens are found | Manual add | Spam / trust handling | Logo + metadata source |
|---|---|---|---|---|
| MetaMask (EVM) | Accounts API index (major chains) or RPC balance sweep over token list; auto-adds ONLY tokens on >=N aggregator lists (occurrenceFloor default 3) (V) | Manage tokens: search, or "Add custom token" by contract address; dapp/explorer "Add to MetaMask" (watchAsset) (V) | Allowlist gate is the spam filter; Security & trust panel (Verified/Suspicious/Malicious); "Low balance tokens" fold (<$1 or unpriced); hide; first-time and lookalike-address send warnings (V) | Token API list, icons proxied via static.cx.metamask.io by address (V) |
| MetaMask (Solana) | All SPL held, then Blockaid bulk scan drops "Malicious" (fail-open), daily rescan auto-hides newly flagged (V) | Search / address (V) | Blockaid (V) | Token API (V) |
| Phantom | Ownership-driven: every SPL / Token-2022 balance appears; "Unknown" if no metadata (V). Internal indexer details unpublished (I) | Not needed for discovery; Manage token list toggles (V) | Auto-hide spam (internal + Blockaid), hidden list, purple check = verified, "This token is unverified", Report as Spam, URL-in-name auto-hide, NFT burn returns rent (V) | Metaplex metadata (on-chain fields before uri JSON), then deprecated Solana token list; prices CoinGecko then Birdeye (V) |
| Rabby | DeBank index per used chain (V) | "Add custom token" by address, multi-chain picker, balance preview (V) | core / unknown / scam flags; non-core hidden from default list; "low-value" fold (<1% of portfolio, cap $1000); user block list; "Scam tx" label (V) | DeBank (V) |
| Rainbow | Rainbow "addys" indexer (V) | Search; no separate contract import found (I) | `probable_spam` auto-hide into Hidden; Verified/Unverified sections in search; Pin/Hide; H shortcut + cmd-K (V) | Indexer icon_url via Imgix proxy; fallback = coloured circle + sanitized symbol (V) |
| Coinbase Wallet / Base app | Indexer (I) | Not documented (I) | Simulation + ML scam detection, "Hide & report", Settings > Display > Hide assets; fake stablecoins show no $ value (V) | Coinbase (I) |
| Family | Not documented (I) | Not documented (I) | Hide vs Trash, "Auto-trash spam", Star, sort by value / market cap / A-Z / custom drag / starred (V) | Not documented (I) |
| Trust Wallet | Not verified (I) | Manage crypto > + > network > contract address, autofilled name/symbol/decimals (I) | Spam-NFT auto-hide, hide < $0.01, security scanner (I, search summaries; support pages 404) | trustwallet/assets repo: logo.png 256x256 + info.json; listing needs 10k holders and 15k tx (V) |
| Backpack (2024 OSS) | GraphQL balances (V) | Not found (I) | "Manage token display" toggles; unverified NFT collections hidden behind "Show All" (V) | Token list entry; grey "?" UNKNOWN_ICON fallback (V) |
| Solflare | Not documented (I) | Not documented (I) | Verified vs unverified labels; "Unverified" NFT folder with Burn / Ignore / Move (V) | Jupiter verification signals (I) |

## (b) Table stakes checklist (what users expect without asking)
List: native token pinned first; sorted by value (else balance / alphabetical); search by name/symbol/address; pin/star; hide/unhide with a Hidden section; zero-balance toggle; low-value fold; a separate spam/unknown section; custom sort (Family). Rows show logo with a chain/trust badge, name, symbol, balance with the right decimals, and fiat value if priced. Long names truncate safely.
States: skeleton loaders for the first load; cached last-known balances offline with a "stale" marker (MetaMask notes RPC/connectivity cause balance issues); pull-to-refresh plus a "Refresh" menu item (MetaMask doc); per-token error state; empty state with Receive and Add token buttons.
Token detail: balance, chart/price if any, Send/Receive/Swap, activity filtered to that token, definition/contract address with copy toast ("Address copied") and explorer link, decimals, supply, which lists include it, trust/security panel, Hide (with confirm), Report.
Send: token picker; paste, QR, address book, recents; ENS/username; format validation; warnings for "this is a token account, not a wallet"; first-time-recipient and lookalike (first 4 + last 4) warnings; long address display; MAX that keeps fees back; fee display and "not enough native token" error; review screen; pending/success/fail with explorer link; add to contacts afterwards.
Receive: QR + full address + copy + share; network label.
Privacy: hide-balances mode (long-press / shimmer); image proxying; opt-out of third-party fetches.
Safety: never trust names; URL-in-name auto-hide; impersonation warning; unhiding doesn't mean verified; airdrop advice "just leave it there".
NFTs: auto-detect, grouped by collection, gallery mode, unverified folder, hide/burn/report, refresh metadata, import by address + id, placeholder for broken media, resize thumbnails.

## (c) Recommended token UX spec for the LEZ wallet (design = INFERRED from evidence above)

Hard facts that shape it (VERIFIED): LEZ definitions carry only `name`, `total_supply`, `authority`, optional `metadata_id`. There is no symbol and no decimals on chain. Holdings carry only `definition_id` + `balance`, with no owner field. Anyone can create your ATA. The indexer has no "tokens by owner" call, but it does index every public account a tx touches.

1. Identity. A token is (network, token program id, definition id). Never key on name or symbol. Show a short definition id wherever two tokens share a symbol.
2. Discovery (an Accounts-API-style service built on the indexer):
   a. Registry sweep: for each definition in (Logos list + user's added + previously seen), derive the ATA (sha256(token_program || owner || definition)) and batch getAccount.
   b. History sweep: page getTransactionsByAccount(owner). For any tx that touches the token or ATA program, decode the definition ids, derive the ATA and fetch it. This catches unsolicited sends, because ATA Create lists the owner.
   c. Live: subscribeToEvents / subscribeToFinalizedBlocks, plus pull-to-refresh and a light poll (MetaMask polls every 3 min).
   d. Non-ATA holdings the wallet creates go in a local store, plus "Import holding by id". Private-account holdings are tracked locally only.
3. Trust tiers (Rabby 3-state + Uniswap ladder + Phantom wording):
   - Verified: on the bundled, signed Logos token list. Gets a check mark, its logo and real symbol/decimals, and counts in totals.
   - Added by you: imported by definition id. Gets an "Added by you" chip. Shown in the main list.
   - Unknown: discovered on chain, not listed, not added. Goes in a collapsed "Unknown tokens (N)" section, excluded from totals, shown with a generated avatar and "Unverified — anyone can create a token with any name".
   - Spam: auto-hidden by local heuristics (URL/domain/t.me in the name, airdrop bait words, TR39-confusable with a Verified symbol/name, bidi or zero-width characters, absurd lengths). Lives in Hidden > Spam.
   - Hidden by you: user-hidden, keyed by definition id, persisted, excluded from re-detection.
   - Unhiding never upgrades trust. Copy: "Showing this token doesn't mean it's safe or verified."
4. Metadata resolution: registry entry, then on-chain `name`, then the metadata `uri` JSON (Simple/Expanded) for symbol, image and decimals. Fetch the uri only for Verified or Added tokens, through our proxy with size/type caps and a cache. Never auto-fetch an unknown token's uri: the attacker controls that server and would learn your IP (MetaMask's privacy copy says image fetches expose IP). Decimals: registry, then metadata, then 0. Show a raw integer plus "decimals unknown" (matches RegistryLoader's "absent ⇒ 0") and let the user set decimals 0–36 on import.
5. Logos. Registry logoURI or metadata image, through the proxy, as a 256px PNG/SVG. Fallback: a deterministic colour from a hash of the definition id plus 1–3 sanitized initials ([A-Za-z0-9] only, as Rainbow does). Never render unknown-token images in the main list. Overlay a badge for verified, and a lock for private holdings.
6. Token list format. Use the Uniswap Token List schema (its address pattern already accepts base58). Put LEZ fields under `extensions`: tokenProgramId, metadataId, network. Use semver as specified (major on removal). Ship it bundled, refresh it remotely, and show the list name and version in token details.
7. Home list. Native first, then pinned, then Verified/Added sorted by value (or balance A–Z when there are no prices). Zero balances hidden by default (toggle), except native and pinned. When prices exist, fold "Low value (N)" items under $1, as MetaMask does. Then the collapsed Unknown (N) section, then a "Manage tokens" link. Manage tokens has search by name/symbol/definition id, a toggle per token, Hidden and Spam tabs, and "Add custom token" at the bottom. Keyboard: cmd-K search and H to hide (Rainbow).
8. Add custom token. Paste a definition id (or a deep link that asks for confirmation, like watchAsset). Validate it: the account exists, its owner is the token program, and it decodes as a TokenDefinition. Errors: "This is a holding account — paste the token's definition id" and "Personal address detected". Prefill name, symbol, decimals and logo, show your balance (Rabby), and warn "Anyone can create a token, including fake versions of existing tokens." If it is TR39-confusable with a Verified token, show a hard warning naming the real definition id.
9. Token detail. Header with logo + trust badge, name, symbol, balance (fiat if any), and Send / Receive / Swap (AMM). Activity filtered to the definition. Details: definition id (copy + explorer), your holding/ATA id (copy + explorer), token program, decimals plus their source, total supply, a supply model row ("Fixed supply" when authority is None, otherwise "Mintable by <id>", like Jupiter's audit.mintAuthorityDisabled), and metadata (standard, uri, creators). Trust panel saying which lists include it ("Logos Token List v1.2.0"; MetaMask's "Token lists"). Menu: Pin, Hide (confirm), Report, Copy link.
10. Send. Token picker (verified first; "Search name / definition id"). Recipient via paste, QR, contacts or recents. Reject definition or holding ids as recipients. Lookalike check (first 4 + last 4 vs history) and a first-time-recipient warning. Show long addresses. If the recipient's ATA is missing, prepend idempotent ATA Create and show "Creates recipient's token account". Enforce decimals, MAX, the sequencer fee (getFeeState), a review screen, pending/final status with explorer link, and "Add to contacts".
11. Receive. Owner address + QR + copy/share. Explain that other wallets deliver tokens to your token account automatically.
12. NFTs. NonFungible definitions and NftMaster/NftPrintedCopy holdings go in Collectibles, grouped by definition. Media comes from the Expanded metadata through the proxy (256px thumbnails, placeholder on error). Unverified collections sit behind "Show all", with Hide / Report / (Burn) and "Refresh metadata". Import by definition or holding id.
13. CLI parity: token list [--hidden|--unknown], token add/hide/unhide/pin <definition>, token info <definition>, all reading the same list and store.

## (d) Research URLs
### Source code read (commit, date)
- https://github.com/MetaMask/core/tree/dc8658bd1c2c57ed9f8d4dae9c12ccab0eacdc5d/packages/assets-controllers/src (TokenDetectionController.ts, token-service.ts, TokensController.ts, assetsUtil.ts, constants.ts, MultichainAssetsController/) 2026-10-06
- https://github.com/MetaMask/metamask-extension (main @a6765b1, 2026-10-02): app/_locales/en/messages.json, ui/pages/asset/components/asset-page.tsx, token-asset.tsx, ui/components/app/assets/token-list/token-list.tsx, ui/components/app/assets/hooks/useLowValueTokenPartition.ts
- https://github.com/RabbyHub/Rabby (@7794bfb, 2026-09-30): src/ui/utils/portfolio/{lpToken,tokenUtils,expandList,token}.ts, src/background/service/preference.ts, _raw/locales/en/messages.json
- https://github.com/rainbow-me/rainbow (@a64ecce, 2026-10-05): src/resources/addys/types.ts, src/state/assets/*, src/utils/CoinIcons/FallbackIcon.js, src/components/coin-icon/RainbowCoinIcon.tsx, src/languages/en_US.json
- https://github.com/coral-xyz/backpack (@5a538a4, 2024-02-14): packages/app-extension/.../TokenDisplayManagementDrawer.tsx, packages/data-components/.../ShowUnverifiedToggle.tsx, packages/common/src/constants.ts, packages/i18n/src/locales/en.json
- https://github.com/Uniswap/token-lists (@01705f9, 2026-03-10): src/tokenlist.schema.json
- https://github.com/Uniswap/interface (main @95fccc9, 2026-10-05): packages/uniswap/src/features/tokens/warnings/safetyUtils.ts
- Local LEZ refs: refs/lez/lez-programs @494dba8 (programs/token/core/src/lib.rs, programs/ata/core/src/lib.rs, programs/ata/src/create.rs, apps/amm/src/RegistryLoader.cpp, apps/token/qml/pages/CreatePage.qml, artifacts/amm-registry.testnet.json); refs/lez/logos-execution-zone @f7fda38 (lez/indexer/service/rpc/src/lib.rs, lez/storage/src/indexer/write_atomic.rs, lee/state_machine/src/public_transaction/transaction.rs)
### Web pages / APIs
- https://accounts.api.cx.metamask.io
- https://benji.org/family-values
- https://blog.uniswap.org/new-token-warnings
- https://cointelegraph.com/news/phantom-chat-address-poisoning-bitcoin-phishing
- https://developer.trustwallet.com/developer/new-asset/requirements.md
- https://developers.jup.ag/docs/tokens/v2
- https://docs.jup.ag/user-docs/launch/vrfd/token-verification
- https://docs.phantom.com/best-practices/tokens/collectibles-nfts-and-semi-fungibles
- https://docs.phantom.com/best-practices/tokens/home-tab-fungibles
- https://docs.phantom.com/best-practices/tokens/token-display
- https://family.co/support
- https://family.co/support/hide-tokens-and-collectibles
- https://family.co/support/sort-tokens-and-collectibles
- https://family.co/support/star-tokens-and-collectibles
- https://family.co/support/trash-tokens-and-collectibles
- https://github.com/RabbyHub/Rabby
- https://github.com/Uniswap/token-lists
- https://github.com/jup-ag/token-list
- https://github.com/solana-labs/token-list/blob/main/README.md
- https://help.coinbase.com/en/wallet/security/fake-stablecoins
- https://help.phantom.com/articles/tokens-or-collectibles-i-received-arent-showing-in-phantom-28975264693267
- https://help.phantom.com/articles/understanding-asset-pages-in-phantom-52633747656211
- https://help.phantom.com/articles/what-are-frozen-tokens-on-solana-29763090277139
- https://help.phantom.com/articles/why-is-my-token-hidden-or-flagged-as-spam-51665009279251
- https://help.phantom.com/hc/en-us/articles/30698882147859
- https://help.phantom.com/hc/en-us/articles/38409446731539
- https://help.phantom.com/hc/en-us/articles/42969287602963
- https://help.phantom.com/hc/en-us/articles/5530158379539-Send-crypto-from-Phantom
- https://help.solflare.com/en/articles/9582028-the-token-i-bought-is-frozen-what-can-i-do
- https://lite-api.jup.ag/tokens/v2/search?query=USDC
- https://metamask.io/news/address-poisoning-detection
- https://metamask.io/news/metamask-ui-update-token-auto-detection
- https://metaplex.com/docs/token-metadata
- https://phantom.com/learn/blog/introducing-burn-nfts
- https://phantom.com/learn/blog/security-at-phantom
- https://phantom.com/learn/crypto-101/common-crypto-scams
- https://rainbow.me/support/app/hide-and-unhide-tokens
- https://rainbow.me/support/extension/hide-and-unhide-tokens-on-the-browser-extension
- https://raw.githubusercontent.com/trustwallet/assets/master/README.md
- https://solana.com/docs/rpc/http/gettokenaccountsbyowner
- https://solana.com/docs/tokens/basics/create-token-account
- https://solana.com/docs/tokens/extensions/metadata
- https://solanacompass.com/tools/solana-token-account-rent-reclaim
- https://static.cx.metamask.io/api/v1/tokenIcons/{chainIdDecimal}/{address}.png
- https://support.metamask.io/configure/privacy/how-to-adjust-metamask-privacy-settings/
- https://support.metamask.io/manage-crypto/nfts/an-nft-is-missing-marked-suspicious-or-not-displaying-correctly-in-metamask-portfolio/
- https://support.metamask.io/manage-crypto/nfts/nft-tokens-in-your-metamask-wallet/
- https://support.metamask.io/manage-crypto/tokens/how-to-display-tokens-in-metamask/
- https://support.metamask.io/manage-crypto/tokens/how-to-remove-a-token/
- https://support.metamask.io/stay-safe/protect-yourself/tokens-and-transactions/how-to-tell-the-difference-between-a-regular-airdrop-and-airdrop-phishing-scams/
- https://support.metamask.io/stay-safe/protect-yourself/wallet-and-hardware/address-poisoning-scams/
- https://support.metamask.io/stay-safe/safety-in-web3/token-safety-practices/
- https://support.uniswap.org/hc/en-us/articles/8723118437133-What-are-token-warnings
- https://token.api.cx.metamask.io
- https://tokens.coingecko.com/solana/all.json
- https://uniswap.org/tokenlist.schema.json
- https://www.coinbase.com/blog/detecting-the-undetectable-coinbase-erc-20-scam-token-detection-system
- https://www.helius.dev/docs/api-reference/das/getassetsbyowner
- https://www.solflare.com/crypto-101/crypto-wallet-security-101-how-solflare-protects-your-assets/
- https://www.unicode.org/reports/tr39/
- https://x.com/CoinbaseSupport/status/1969967423227900407
- https://x.com/phantom/status/1427669854274736140
- https://x.com/phantom/status/1569732862978715648
