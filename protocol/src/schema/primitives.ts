import Type from 'typebox'

/**
 * CAIP-2 chain id. LEZ zones use the `lez` namespace (e.g. `lez:testnet`);
 * the Logos L1 will use its own namespace (LP-0022). Chains are data, never
 * constants: a wallet can hold several zones, each with its own sequencer.
 */
export const ChainId = Type.String({
  pattern: '^[-a-z0-9]{3,8}:[-_a-zA-Z0-9]{1,32}$',
  description: 'CAIP-2 chain id, e.g. "lez:testnet"',
})

/** Base58 LEZ account id (32 bytes). Public accounts and program header accounts. */
export const AccountId = Type.String({
  pattern: '^[1-9A-HJ-NP-Za-km-z]{32,44}$',
  description: 'Base58-encoded 32-byte LEZ account id',
})

/**
 * Opaque, per-origin handle for a private account. Two dApps never see the
 * same handle for the same private account (LWS-0 §8.4 rule 4).
 */
export const PrivateHandle = Type.String({
  pattern: '^pvt_[A-Za-z0-9_-]{16,64}$',
  description: 'Opaque per-origin private account handle',
})

/** 0x-prefixed lowercase hex. */
export const Hex = Type.String({ pattern: '^0x[0-9a-f]*$' })

/** 32-byte hash as 0x-hex (tx hashes, image ids). */
export const Hash32 = Type.String({ pattern: '^0x[0-9a-f]{64}$' })

/**
 * Basecamp intent payloads cap strings at 64 KB and whole payloads at 1000
 * nodes (IntentBroker). Byte fields and arrays are capped below those limits
 * so an oversized request fails validation with a clear error, not the
 * shell's generic `bad_request`.
 */
export const INTENT_MAX_STRING = 65_000

/** Standard base64 (RFC 4648 §4, with padding). Used for byte payloads. */
export const Base64 = Type.String({
  pattern: '^[A-Za-z0-9+/]*={0,2}$',
  maxLength: INTENT_MAX_STRING,
})

/**
 * Unsigned integer amount as a decimal string. LEZ balances are u128, which
 * exceeds JSON's safe-integer range and Basecamp intent payload limits (±2^53).
 */
export const U128 = Type.String({
  pattern: '^(0|[1-9][0-9]{0,38})$',
  description:
    'u128 as a decimal string. The pattern allows up to 39 digits; values above 2^128-1 are rejected by the codec and wallet with -32602.',
})

/** RFC 3339 timestamp. */
export const Timestamp = Type.String({ format: 'date-time' })

export const AccountKind = Type.Union([Type.Literal('public'), Type.Literal('private')])
