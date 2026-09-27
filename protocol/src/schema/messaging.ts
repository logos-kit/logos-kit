import Type from 'typebox'
import { AccountId, Base64, ChainId, Hash32, PrivateHandle, U128 } from './primitives.ts'

export const SignMessageParams = Type.Object({
  account: AccountId,
  /** Raw bytes to sign; the wallet signs BIP-340 over tagged hash `LEZ/message/v1`. */
  message: Base64,
})

export const SignMessageResult = Type.Object({
  signature: Base64,
  publicKey: Base64,
  tag: Type.Literal('LEZ/message/v1'),
})

export const RequestFundsParams = Type.Object({
  chain: ChainId,
  /** Target account. A private target is funded via a public account + shield. */
  account: Type.Union([AccountId, PrivateHandle]),
})

export const RequestFundsResult = Type.Object({
  status: Type.Union([
    Type.Literal('funded'),
    Type.Literal('rate_limited'),
    Type.Literal('rejected'),
    Type.Literal('outcome_unknown'),
  ]),
  amount: Type.Optional(U128),
  /** Seconds until the faucet accepts another claim (rate_limited). */
  retryAfterSeconds: Type.Optional(Type.Integer({ minimum: 0 })),
  txHash: Type.Optional(Hash32),
  /** Present when the target was private and a follow-up shield was queued. */
  shieldHandle: Type.Optional(Type.String()),
  reason: Type.Optional(Type.String({ maxLength: 256 })),
})

export const BalanceParams = Type.Object({
  chain: ChainId,
  account: Type.Union([AccountId, PrivateHandle]),
  /** Omit for the native token; otherwise the token definition account. */
  asset: Type.Optional(AccountId),
})

export const BalanceResult = Type.Object({
  asset: Type.Union([Type.Literal('native'), AccountId]),
  amount: U128,
  /** For private accounts: false while the wallet is still scanning. */
  synced: Type.Boolean(),
  /** Last block the value reflects. */
  asOfBlock: Type.Optional(Type.String({ pattern: '^[0-9]+$' })),
})

/** `lez_readAccount`: a public account's slot for one program, as the node holds it now. */
export const ReadAccountParams = Type.Object({
  chain: ChainId,
  account: AccountId,
  /** The program whose data to read (the native token program for balances). */
  program: AccountId,
})

/**
 * `lez_openExplorer`: open the zone's explorer at one transaction or account.
 * The wallet builds the URL, so apps can't open arbitrary links through it.
 */
export const OpenExplorerParams = Type.Object({
  chain: ChainId,
  txHash: Type.Optional(Hash32),
  account: Type.Optional(AccountId),
})

export const OpenExplorerResult = Type.Object({ url: Type.String() })

export const ReadAccountResult = Type.Object({
  nonce: U128,
  /** The program's data on this account (borsh), base64; empty if none. */
  data: Base64,
})
