// QML-safe module: ES2017 only (no BigInt, no Intl, no optional chaining, and
// `declare` fields so the build emits no class-field syntax; see check-qml.ts).

/**
 * LWS-0 error codes.
 * - 4xxx: EIP-1193 (verbatim, so every kit maps 4001 → "user rejected").
 * - 57xx: EIP-5792 batch/capability errors.
 * - 61xx: LEZ-specific.
 */
export const ErrorCode = {
  UserRejected: 4001,
  Unauthorized: 4100,
  UnsupportedMethod: 4200,
  Disconnected: 4900,
  ChainDisconnected: 4901,
  UnknownChain: 4902,
  InvalidParams: -32602,
  Internal: -32603,
  UnsupportedCapability: 5700,
  DuplicateId: 5720,
  UnknownHandle: 5730,
  BatchTooLarge: 5740,
  AtomicityUnsupported: 5760,
  AccountKindUnsupported: 6100,
  SimulationFailed: 6101,
  ProofFailed: 6102,
  SubmissionFailed: 6103,
  InvalidProposal: 6104,
  OriginAttestationRequired: 6105,
  StaleApproval: 6106,
  RequestPending: 6107,
  Timeout: 6108,
  Unavailable: 6109,
} as const

export type ErrorCodeValue = (typeof ErrorCode)[keyof typeof ErrorCode]

const DOCS_BASE = 'https://docs.logos-kit.dev/errors'

/** Short, user-safe default messages (see docs/design/ux-spec.md §11). */
const defaultMessages: { [code: number]: string } = {
  4001: 'Request declined',
  4100: "This app isn't connected to that account",
  4200: "The wallet doesn't support this request",
  4900: 'Wallet disconnected',
  4901: 'Network disconnected',
  4902: 'Unknown network',
  5700: 'Unsupported capability',
  5720: 'Duplicate request id',
  5730: 'Unknown transaction handle',
  5740: 'Too many instructions',
  5760: "Atomic execution isn't supported",
  6100: "This account type can't do that",
  6101: "Couldn't simulate this transaction",
  6102: 'Proof failed: nothing was sent',
  6103: 'The sequencer rejected the transaction',
  6104: 'Invalid transaction proposal',
  6105: 'Origin could not be verified',
  6106: 'Something changed since you approved. Please review again',
  6107: 'A request is already open in your wallet',
  6108: "The wallet didn't respond",
  6109: "The wallet isn't available",
}

export type LezErrorJson = { code: number; message: string; data?: unknown }

/**
 * Base error for every LWS-0 failure. Wire form is always `{ code, message, data }`;
 * this class adds viem-style ergonomics (`shortMessage`, `docsUrl`, `walk`).
 */
export class LezError extends Error {
  declare readonly code: number
  declare readonly shortMessage: string
  declare readonly data: unknown
  declare readonly docsUrl: string

  constructor(code: number, message?: string, data?: unknown, options?: { cause?: unknown }) {
    const short = message || defaultMessages[code] || 'Wallet error'
    super(short)
    this.name = 'LezError'
    this.code = code
    this.shortMessage = short
    this.data = data
    this.docsUrl = `${DOCS_BASE}#${code}`
    if (options && options.cause !== undefined) {
      ;(this as { cause?: unknown }).cause = options.cause
    }
    Object.setPrototypeOf(this, new.target.prototype)
  }

  /**
   * Walk the `cause` chain; returns the first error matching `fn` (or the
   * deepest). Stops after 16 links so a cyclic chain can't hang the UI thread.
   */
  walk(fn?: (err: unknown) => boolean): unknown {
    let current: unknown = this
    let last: unknown = this
    for (let depth = 0; current && depth < 16; depth++) {
      if (fn && fn(current)) return current
      last = current
      current = (current as { cause?: unknown }).cause
    }
    return fn ? null : last
  }

  toJSON(): LezErrorJson {
    return this.data === undefined
      ? { code: this.code, message: this.shortMessage }
      : { code: this.code, message: this.shortMessage, data: this.data }
  }

  static fromJSON(json: LezErrorJson): LezError {
    return new LezError(json.code, json.message, json.data)
  }
}

export function isLezError(err: unknown): err is LezError {
  return (
    err instanceof LezError ||
    (typeof err === 'object' && err !== null && (err as { name?: unknown }).name === 'LezError')
  )
}

export function isUserRejection(err: unknown): boolean {
  return isLezError(err) && err.code === ErrorCode.UserRejected
}

/**
 * Basecamp intent error codes (frozen vocabulary, LogosIntent.h) mapped to LWS-0.
 * `unavailable` merges "not installed" and "denied" by design; keep it that way.
 */
export function fromIntentError(code: string): LezError {
  switch (code) {
    case 'cancelled':
      return new LezError(ErrorCode.UserRejected)
    case 'timeout':
      return new LezError(ErrorCode.Timeout)
    case 'unavailable':
      return new LezError(ErrorCode.Unavailable)
    case 'bad_request':
      return new LezError(ErrorCode.InvalidParams, 'Invalid request')
    // The shell coerces every other provider error to `failed` and carries no
    // detail; the wallet showed the reason to the user.
    case 'failed':
      return new LezError(ErrorCode.Internal, "The wallet couldn't complete the request")
    case 'not_declared':
      return new LezError(
        ErrorCode.Internal,
        'The app did not declare this intent in its metadata.json "uses"',
      )
    default:
      return new LezError(ErrorCode.Internal, 'Wallet request failed')
  }
}
