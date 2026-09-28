// Hand-written behaviour for the generated method reference. The schema says
// what a method takes and returns; these notes say what the wallet actually
// does with it (limits, side effects, gates). gen-reference.mjs merges them
// under each method. Keep them true to crates/wallet-engine/src/service.rs.
export const notes = {
  lez_chainId: `
- Answers any caller, with or without a session: the network is public
  metadata, like \`eth_chainId\`. It never reveals accounts or balances.
- The value changes when the user switches networks in the wallet. The QML SDK
  checks it on start, when your view is shown, and every 5 s while visible,
  and rebuilds \`kit.api\` when it changes (set \`followWallet: false\` to pin a
  network).
`,
  lez_openExplorer: `
- Opens the page in the user's browser (an OS side effect), because the
  Basecamp QML sandbox can't open links itself. The result's \`url\` is the
  page it opened.
- The URL is built by the wallet from a fixed base. Only \`lez:testnet\` has an
  explorer (\`https://explorer.testnet.lez.logos.co\`); other networks answer
  \`5700\`. A \`chain\` other than the wallet's current one answers \`4902\`.
- Pass **exactly one** of \`txHash\` (32 bytes of hex, optional \`0x\`) or
  \`account\` (a valid account id); anything else is \`InvalidParams\`.
- Rate-limited: at most one page per second across all apps (\`6107\` otherwise).
- Only apps with a connected session can call it.
`,
  lez_requestFunds: `
- Opens the wallet's faucet sheet (the testnet faucet, or the debug genesis
  faucet on a local sequencer). The account must be one the
  user shared with your app; otherwise \`Unauthorized\`.
- The faucet only pays **public** accounts. For a private target the wallet
  pays one of the user's public accounts (returned as \`fundedAccount\`) and
  queues a shield into the private account for the user to approve
  (\`shieldHandle\`). That public account is linked to the private one on
  chain, and the sheet says so.
- \`status\` is \`funded\`, \`rate_limited\` (with \`retryAfterSeconds\`),
  \`outcome_unknown\` or \`rejected\` (with \`reason\`). On \`outcome_unknown\`,
  don't request again: watch the balance of \`fundedAccount\` (or the target, when
  it is public) for a bounded time, because a second request could pay twice.
`,
}
