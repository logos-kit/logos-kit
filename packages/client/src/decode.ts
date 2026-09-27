// Node responses → typed values. Balances and nonces are decimal strings.
import {
  type AccountId,
  decodeTransaction,
  fromBase64,
  NATIVE_TOKEN_PROGRAM,
  type PublicTransaction,
  Reader,
  readTransaction,
  readUle,
  toHex,
} from '@logos-kit/codec'
import { decimal } from './json.ts'

export interface Account {
  nonce: string
  /** Program account → that program's data on this account. */
  shards: Record<AccountId, Uint8Array>
}

export function decodeAccount(v: unknown): Account {
  const a = v as { nonce: unknown; data?: { shards?: Record<string, number[]> } }
  const shards: Record<AccountId, Uint8Array> = {}
  const raw = (a.data && a.data.shards) || {}
  for (const k of Object.keys(raw)) shards[k] = new Uint8Array(raw[k] as number[])
  return { nonce: decimal(a.nonce), shards }
}

/** Native balance held in an account's native-token shard (u128 LE). */
export function nativeBalance(account: Account): string {
  const s = account.shards[NATIVE_TOKEN_PROGRAM]
  return s && s.length ? readUle(s.subarray(0, 16)) : '0'
}

export interface BlockHeader {
  id: string
  hash: string
  prevHash: string
  /** Unix ms. */
  timestamp: number
  producer: string
}

export interface Block {
  header: BlockHeader
  /** Public transactions, when every transaction in the block is public. */
  transactions?: PublicTransaction[]
  /** Number of transactions (always known). */
  transactionCount: number
  /** The borsh block, base64, for callers that need the rest. */
  raw: string
}

export function decodeBlock(b64: string): Block {
  const bytes = fromBase64(b64)
  const r = new Reader(bytes)
  const id = r.u64()
  const prevHash = toHex(r.fixed(32))
  const hash = toHex(r.fixed(32))
  const timestamp = Number(r.u64())
  const producer = toHex(r.fixed(32))
  r.fixed(64) // producer signature
  const count = r.u32()
  const header = { id, hash, prevHash, timestamp, producer }
  // A private transaction has no length prefix; decoding stops at the first one.
  const transactions: PublicTransaction[] = []
  try {
    for (let i = 0; i < count; i++) {
      if (r.u8() !== 0) return { header, transactionCount: count, raw: b64 }
      transactions.push(readTransaction(r))
    }
  } catch {
    return { header, transactionCount: count, raw: b64 }
  }
  return { header, transactions, transactionCount: count, raw: b64 }
}

export type TransactionEnvelope =
  | { kind: 'public'; transaction: PublicTransaction; block: string }
  | { kind: 'private'; raw: string; block: string }

/** `getTransaction`'s `[base64 LeeTransaction, blockId]`. */
export function decodeTransactionResult(v: unknown): TransactionEnvelope | null {
  if (v === null || v === undefined) return null
  const [b64, block] = v as [string, unknown]
  const bytes = fromBase64(b64)
  if (bytes[0] === 0) {
    return {
      kind: 'public',
      transaction: decodeTransaction(bytes.subarray(1)),
      block: decimal(block),
    }
  }
  return { kind: 'private', raw: b64, block: decimal(block) }
}
