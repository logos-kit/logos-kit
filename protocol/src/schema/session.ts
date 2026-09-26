import Type from 'typebox'
import { AccountId, AccountKind, Base64, ChainId, PrivateHandle, Timestamp } from './primitives.ts'

/**
 * Capability-scoped grants. A dApp is granted specific capabilities per
 * account; a proof request is deliberately separate from account access
 * (LP-0001 hook: prove ownership without revealing the account).
 */
export const Capability = Type.Union([
  Type.Literal('accounts'),
  Type.Literal('read_public'),
  Type.Literal('read_private'),
  Type.Literal('propose_tx'),
  Type.Literal('sign_message'),
  Type.Literal('request_proof'),
])

export const WalletAccount = Type.Object({
  /** Public account id, or an opaque per-origin handle for private accounts. */
  address: Type.Union([AccountId, PrivateHandle]),
  kind: AccountKind,
  chain: ChainId,
  /** 32-byte x-only BIP-340 public key (public accounts only). */
  publicKey: Type.Optional(Base64),
  label: Type.Optional(Type.String({ maxLength: 64 })),
  /** Capabilities granted to the requesting origin for this account. */
  capabilities: Type.Array(Capability),
})

export const Capabilities = Type.Object({
  accountKinds: Type.Array(AccountKind),
  /** False for wallets that must own submission (all private flows). */
  signTransaction: Type.Boolean(),
  batch: Type.Object({
    maxInstructions: Type.Integer({ minimum: 1, maximum: 16 }),
    atomic: Type.Union([Type.Literal('supported'), Type.Literal('unsupported')]),
  }),
  proving: Type.Optional(
    Type.Object({
      location: Type.Union([
        Type.Literal('local'),
        Type.Literal('paired'),
        Type.Literal('user-owned'),
        Type.Literal('tee'),
      ]),
      typicalSeconds: Type.Optional(Type.Integer({ minimum: 0 })),
    }),
  ),
  outcomeVerification: Type.Array(
    Type.Union([
      Type.Literal('own-account-invariant'),
      Type.Literal('program-event'),
      Type.Literal('node'),
    ]),
  ),
  signMessage: Type.Boolean(),
  signIn: Type.Boolean(),
  requestFunds: Type.Boolean(),
})

export const SignInRequest = Type.Object({
  domain: Type.String({ maxLength: 253 }),
  statement: Type.Optional(Type.String({ maxLength: 512 })),
  uri: Type.String({ maxLength: 2048 }),
  nonce: Type.String({ minLength: 8, maxLength: 64 }),
  issuedAt: Timestamp,
  expirationTime: Type.Optional(Timestamp),
  notBefore: Type.Optional(Timestamp),
  requestId: Type.Optional(Type.String({ maxLength: 64 })),
})

export const SignInResult = Type.Object({
  account: WalletAccount,
  /** The exact UTF-8 text that was signed (SIWE-shaped). */
  signedMessage: Type.String(),
  /** 64-byte BIP-340 signature over tagged hash `LEZ/signin/v1`. */
  signature: Base64,
})

export const ConnectParams = Type.Object({
  chains: Type.Array(ChainId, { minItems: 1 }),
  /** Default ['public']. 'private' triggers a separate, explicit consent. */
  accountKinds: Type.Optional(Type.Array(AccountKind)),
  capabilities: Type.Optional(Type.Array(Capability)),
  /** Restore an existing session without UI, or fail with 4100. */
  silent: Type.Optional(Type.Boolean()),
  signIn: Type.Optional(SignInRequest),
})

export const Session = Type.Object({
  sessionId: Type.String({ minLength: 16, maxLength: 128 }),
  /** Origin as ATTESTED by the transport (Basecamp shell, browser, pairing). Echoed for transparency. */
  origin: Type.String(),
  chains: Type.Array(ChainId),
  accounts: Type.Array(WalletAccount),
  expiry: Type.Optional(Timestamp),
  capabilities: Capabilities,
  signIn: Type.Optional(SignInResult),
})
