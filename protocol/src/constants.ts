// QML-safe module: ES2017 only.

/** LWS-0 protocol version. Bump on any breaking change to methods or schemas. */
export const LWS_VERSION = '0.1.0'

export const METHODS = {
  connect: 'lez_connect',
  disconnect: 'lez_disconnect',
  getSession: 'lez_getSession',
  getAccounts: 'lez_getAccounts',
  getCapabilities: 'lez_getCapabilities',
  getBalance: 'lez_getBalance',
  readAccount: 'lez_readAccount',
  chainId: 'lez_chainId',
  openExplorer: 'lez_openExplorer',
  signAndSendTransaction: 'lez_signAndSendTransaction',
  getTransactionStatus: 'lez_getTransactionStatus',
  signMessage: 'lez_signMessage',
  signIn: 'lez_signIn',
  requestFunds: 'lez_requestFunds',
  switchChain: 'lez_switchChain',
} as const

export const NOTIFICATIONS = {
  accountsChanged: 'lez_accountsChanged',
  chainChanged: 'lez_chainChanged',
  sessionChanged: 'lez_sessionChanged',
  disconnected: 'lez_disconnected',
  transactionUpdated: 'lez_transactionUpdated',
  capabilitiesChanged: 'lez_capabilitiesChanged',
} as const

/**
 * Basecamp intents provided by the Logos Kit wallet UI. Names follow the shell
 * grammar (namespace.verb, 2–4 segments, lowercase). `logos.*` and `basecamp.*`
 * are reserved by the platform.
 */
export const INTENTS = {
  connect: 'lez.wallet.connect',
  sendTransaction: 'lez.transaction.send',
  signMessage: 'lez.message.sign',
  signIn: 'lez.wallet.sign_in',
  requestFunds: 'lez.wallet.request_funds',
  open: 'lez.wallet.open',
} as const

/** BIP-340 tagged-hash domains (tag → SHA256(SHA256(tag)‖SHA256(tag)‖msg)). */
export const SIGNING_TAGS = {
  message: 'LEZ/message/v1',
  signIn: 'LEZ/signin/v1',
} as const

/** Default Basecamp core module the SDK talks to for reads and status. */
export const WALLET_CORE_MODULE = 'logos_kit_wallet'

/** Well-known zones. Zones are data: wallets may add more at runtime. */
export const CHAINS = {
  lezTestnet: 'lez:testnet',
  lezLocal: 'lez:local',
} as const
