// Screens the docs show, by name → source capture (repo-relative).
// `panel`: a wallet or app view captured at 2x by the dev harness
// (modules/logos_kit_wallet_ui/dev/*harness.py). `window`: a full Basecamp
// window (e2e/basecamp-*.sh, e2e/catalog-install-gui.sh).
// Re-shoot the sources, then `pnpm shots` (see scripts/shots.mjs).
export const shots = {
  // Wallet
  'wallet-welcome': {
    src: 'docs/reviews/s7/catalog/06-wallet-opens.png',
    kind: 'window',
    alt: 'Logos Kit Wallet opening in Basecamp after a catalog install, on the preview network',
  },
  'wallet-home-private': {
    src: 'docs/reviews/s7/07-home-private-480.png',
    kind: 'panel',
    alt: 'Wallet home showing a private balance only the owner can see',
  },
  'wallet-home-public': {
    src: 'docs/reviews/s7/10-home-public-480.png',
    kind: 'panel',
    alt: 'Wallet home for a public account',
  },
  'wallet-home-light': {
    src: 'docs/reviews/s7/43-home-light-480.png',
    kind: 'panel',
    light: true,
    alt: 'Wallet home in the light theme',
  },
  'wallet-send-review': {
    src: 'docs/reviews/s7/13-send-review-480.png',
    kind: 'panel',
    alt: 'Reviewing a send before approving it',
  },
  'wallet-proving': {
    src: 'docs/reviews/s7/14-send-proving-480.png',
    kind: 'panel',
    alt: 'A private send proving on the device, with its steps',
  },
  'wallet-private-review': {
    src: 'docs/reviews/s7/40-private-review-480.png',
    kind: 'panel',
    alt: 'Reviewing a private transfer',
  },
  'wallet-accounts': {
    src: 'docs/reviews/s7/17-accounts-480.png',
    kind: 'panel',
    alt: 'Public and private accounts in the wallet',
  },
  'wallet-settings': {
    src: 'docs/reviews/s7/18-settings-480.png',
    kind: 'panel',
    alt: 'Wallet settings: network, auto-lock, connected apps',
  },
  'wallet-phrase': {
    src: 'docs/reviews/s7/04-phrase-480.png',
    kind: 'panel',
    alt: 'The recovery phrase shown once at wallet creation',
  },
  'wallet-connect': {
    src: 'docs/reviews/s8/testimonial/02-wallet-connect-440.png',
    kind: 'panel',
    alt: 'An app asking to connect: the accounts to share and what it may do',
  },
  'wallet-approval': {
    src: 'docs/reviews/s8/testimonial/09-wallet-approval-440.png',
    kind: 'panel',
    alt: 'Approving a testimonial post: decoded, source-verified, with the fee cap',
  },
  'wallet-sign-message': {
    src: 'docs/reviews/s7/23-sign-message-480.png',
    kind: 'panel',
    alt: 'Signing a message for an app',
  },
  'wallet-shield': {
    src: 'docs/reviews/s8/faucet/08-wallet-shield-440.png',
    kind: 'panel',
    alt: 'Approving a shield into a private account',
  },
  // Testimonial app
  'testimonial-compose': {
    src: 'docs/reviews/s8/testimonial/07-compose-520.png',
    kind: 'panel',
    alt: 'The testimonial app: composing a post that names the wallet',
  },
  'testimonial-no-funds': {
    src: 'docs/reviews/s8/testimonial/03-no-funds-520.png',
    kind: 'panel',
    alt: 'A fresh account with no funds, offered test funds in-flow',
  },
  'testimonial-pending': {
    src: 'docs/reviews/s8/testimonial/10-pending-520.png',
    kind: 'panel',
    alt: 'A testimonial post on its way to a block',
  },
  'testimonial-done': {
    src: 'docs/reviews/s8/testimonial/11-done-520.png',
    kind: 'panel',
    alt: 'A testimonial post included and confirmed from its on-chain record',
  },
  'testimonial-basecamp': {
    src: 'docs/reviews/s8/basecamp/12-testimonial-done.png',
    kind: 'window',
    alt: 'The testimonial app in Basecamp after a post landed',
  },
  // Faucet app
  'faucet-accounts': {
    src: 'docs/reviews/s8/faucet/02-accounts-520.png',
    kind: 'panel',
    alt: 'The faucet app: picking a public or private account',
  },
  'faucet-funded': {
    src: 'docs/reviews/s8/faucet/03-funded-520.png',
    kind: 'panel',
    alt: 'Test funds arrived',
  },
  'faucet-rate-limited': {
    src: 'docs/reviews/s8/faucet/04-rate-limited-520.png',
    kind: 'panel',
    alt: 'Rate limited, with a countdown',
  },
  'faucet-proving': {
    src: 'docs/reviews/s8/faucet/09-shield-proving-520.png',
    kind: 'panel',
    alt: 'Moving test funds into a private account: proving',
  },
  'faucet-private-funded': {
    src: 'docs/reviews/s8/faucet/10-private-funded-520.png',
    kind: 'panel',
    alt: 'Test funds arrived in a private account',
  },
  'faucet-unconfirmed': {
    src: 'docs/reviews/s8/faucet/11-unconfirmed-520.png',
    kind: 'panel',
    alt: 'Outcome not confirmed yet, with a safe re-check',
  },
  // Template
  'template-receipt': {
    src: 'docs/reviews/s8/template/05-receipt-480.png',
    kind: 'panel',
    alt: 'The dApp template showing a transaction receipt',
  },
  // Catalog install
  'catalog-add': {
    src: 'docs/reviews/s7/catalog/01-add-repository.png',
    kind: 'window',
    alt: 'Adding the Logos Kit catalog in Basecamp settings',
  },
  'catalog-install': {
    src: 'docs/reviews/s7/catalog/04-install-dialog.png',
    kind: 'window',
    alt: 'Installing Logos Kit Wallet from the catalog',
  },
}
