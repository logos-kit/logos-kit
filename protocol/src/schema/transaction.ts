import Type from 'typebox'
import { AccountId, Base64, ChainId, Hash32, PrivateHandle, Timestamp, U128 } from './primitives.ts'

/** Account reference inside a proposal: public id or the origin's private handle. */
export const AccountRef = Type.Union([AccountId, PrivateHandle])

export const Instruction = Type.Object({
  /** The program's header account (v0.3: programs are addressed by header, not image id). */
  program: AccountId,
  accounts: Type.Array(
    Type.Object({
      account: AccountRef,
      writable: Type.Boolean(),
      signer: Type.Boolean(),
    }),
    { maxItems: 64 },
  ),
  /** Borsh-encoded instruction bytes (v0.3). */
  data: Base64,
  /** Advisory only. The wallet MUST decode `data` itself when it can. */
  display: Type.Optional(
    Type.Object({
      method: Type.Optional(Type.String({ maxLength: 64 })),
      args: Type.Optional(Type.Record(Type.String(), Type.Unknown())),
    }),
  ),
})

export const TransactionProposal = Type.Object({
  chain: ChainId,
  /** The account paying the fee and signing (public), or spending (private). */
  account: AccountRef,
  /** Optional dApp-chosen id, unique per (origin, account). */
  id: Type.Optional(Type.String({ minLength: 1, maxLength: 64 })),
  instructions: Type.Array(Instruction, { minItems: 1, maxItems: 16 }),
  /** Reject with 5760 if atomic execution of all instructions isn't possible. */
  atomicRequired: Type.Optional(Type.Boolean()),
})

export const SubmitResult = Type.Object({
  /** Wallet-issued handle. Exists before a tx hash does (proving can take minutes). */
  handle: Type.String({ minLength: 16, maxLength: 128 }),
  txHash: Type.Optional(Hash32),
})

/** Inclusion lifecycle. INCLUDED never implies success; see `outcome`. */
export const Lifecycle = Type.Union([
  Type.Literal('awaiting_approval'),
  Type.Literal('building'),
  Type.Literal('proving'),
  Type.Literal('signing'),
  Type.Literal('submitted'),
  Type.Literal('included'),
  Type.Literal('finalized'),
  Type.Literal('rejected'),
  Type.Literal('dropped'),
  Type.Literal('expired'),
])

/**
 * LEZ has no receipts, and v0.3 includes failed transactions. `outcome` is set
 * only from evidence (a program event, or an own-account invariant such as
 * nonce advanced plus the expected balance delta); otherwise it stays unknown.
 */
export const Outcome = Type.Union([
  Type.Literal('success'),
  Type.Literal('failure'),
  Type.Literal('unknown'),
])

export const OutcomeSource = Type.Union([
  Type.Literal('own-account-invariant'),
  Type.Literal('program-event'),
  Type.Literal('node'),
  Type.Literal('none'),
])

export const Effect = Type.Object({
  account: AccountRef,
  field: Type.Union([
    Type.Literal('balance'),
    Type.Literal('token_balance'),
    Type.Literal('data'),
    Type.Literal('authority'),
    Type.Literal('nonce'),
  ]),
  asset: Type.Optional(Type.String()),
  before: Type.Optional(Type.String()),
  after: Type.Optional(Type.String()),
})

export const FeeInfo = Type.Object({
  /** Maximum fee the user approved (native units, decimal string). */
  estimatedMax: Type.Optional(U128),
  /** Fee actually charged, when observable; absent means "unavailable". */
  used: Type.Optional(U128),
  gasLimit: Type.Optional(Type.String({ pattern: '^[0-9]+$' })),
})

export const TransactionStatus = Type.Object({
  handle: Type.String(),
  chain: ChainId,
  txHash: Type.Optional(Hash32),
  lifecycle: Lifecycle,
  outcome: Outcome,
  outcomeSource: OutcomeSource,
  block: Type.Optional(
    Type.Object({ id: Type.String({ pattern: '^[0-9]+$' }), timestamp: Type.Optional(Timestamp) }),
  ),
  expectedEffects: Type.Optional(Type.Array(Effect)),
  observedEffects: Type.Optional(Type.Array(Effect)),
  fee: Type.Optional(FeeInfo),
  proving: Type.Optional(
    Type.Object({
      phase: Type.Union([
        Type.Literal('preparing'),
        Type.Literal('proving'),
        Type.Literal('submitting'),
        Type.Literal('waiting_for_block'),
      ]),
      /** 0–100, monotonic. Absent when not measurable. */
      progress: Type.Optional(Type.Number({ minimum: 0, maximum: 100 })),
      etaSeconds: Type.Optional(Type.Integer({ minimum: 0 })),
      startedAt: Type.Optional(Timestamp),
    }),
  ),
  error: Type.Optional(
    Type.Object({
      code: Type.Integer(),
      message: Type.String(),
      data: Type.Optional(Type.Unknown()),
    }),
  ),
})
