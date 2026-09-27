// LEZ 0.3 public transactions, byte-exact with `lee::public_transaction`.
import { type AccountId, accountBytes, type ShardSelector } from './account.ts'
import { u64, u128 } from './amount.ts'
import { Reader, Writer } from './borsh.ts'
import { type Bytes, concat, equal, toBase58, toBase64, toHex, utf8 } from './bytes.ts'
import { sha256 } from './sha256.ts'

export interface FeeDeclaration {
  /** Debited for the fee; must sign. */
  payer: AccountId
  gasLimit: string
  tip: string
  maxFee: string
}

export interface PublicMessage {
  program: AccountId
  shardSelectors: ShardSelector[]
  /** One per signer, in witness order (decimal u128). */
  nonces: string[]
  instructionData: Bytes
  /** `null` only for fee-exempt system transactions. */
  fee: FeeDeclaration | null
}

export interface Witness {
  /** 64-byte BIP-340 signature. */
  signature: Bytes
  /** 32-byte x-only public key. */
  publicKey: Bytes
}

export interface PublicTransaction {
  message: PublicMessage
  witnesses: Witness[]
}

/** LEZ wallet defaults (`wallet::DEFAULT_GAS_LIMIT`, `max_fee_for`). */
export const DEFAULT_GAS_LIMIT = '2000000'
export function defaultMaxFee(gasLimit: string): string {
  // (gas_limit + 100_000 assumed data bytes) * 64 assumed base fee
  const n = Number(u64(gasLimit))
  if (n > 2 ** 40) throw new Error('gas limit too large for the default max fee')
  return u128(String((n + 100000) * 64))
}

const pad32 = (s: string): Bytes => {
  const b = new Uint8Array(32)
  b.set(utf8(s))
  return b
}
const MESSAGE_PREFIX = pad32('/LEE/v0.3/Message/Public/')

function writeMessage(w: Writer, m: PublicMessage): void {
  w.fixed(accountBytes(m.program))
  w.vec(m.shardSelectors, (w, s) => {
    w.fixed(accountBytes(s.account)).fixed(accountBytes(s.program))
  })
  w.vec(m.nonces, (w, n) => {
    w.u128(n)
  })
  w.bytes(m.instructionData)
  w.option(m.fee, (w, f) => {
    w.fixed(accountBytes(f.payer)).u64(f.gasLimit).u64(f.tip).u128(f.maxFee)
  })
}

const readAccount = (r: Reader): AccountId => toBase58(r.fixed(32))

function readMessage(r: Reader): PublicMessage {
  return {
    program: readAccount(r),
    shardSelectors: r.vec((r) => ({ account: readAccount(r), program: readAccount(r) })),
    nonces: r.vec((r) => r.u128()),
    instructionData: r.bytes(),
    fee: r.option((r) => ({
      payer: readAccount(r),
      gasLimit: r.u64(),
      tip: r.u64(),
      maxFee: r.u128(),
    })),
  }
}

export function encodeMessage(m: PublicMessage): Bytes {
  const w = new Writer()
  writeMessage(w, m)
  return w.toBytes()
}

export function decodeMessage(b: Bytes): PublicMessage {
  const r = new Reader(b)
  const m = readMessage(r)
  r.end()
  return m
}

/** What each signer signs: `sha256(prefix || borsh(message))`. */
export const messageHash = (m: PublicMessage): Bytes =>
  sha256(concat(MESSAGE_PREFIX, encodeMessage(m)))

export function encodeTransaction(tx: PublicTransaction): Bytes {
  const w = new Writer()
  writeMessage(w, tx.message)
  w.vec(tx.witnesses, (w, x) => {
    if (x.signature.length !== 64 || x.publicKey.length !== 32) throw new Error('bad witness')
    w.fixed(x.signature).fixed(x.publicKey)
  })
  return w.toBytes()
}

/** Read one public transaction from `r` (e.g. inside a block body). */
export function readTransaction(r: Reader): PublicTransaction {
  const message = readMessage(r)
  const witnesses = r.vec((r) => ({ signature: r.fixed(64), publicKey: r.fixed(32) }))
  return { message, witnesses }
}

export function decodeTransaction(b: Bytes): PublicTransaction {
  const r = new Reader(b)
  const tx = readTransaction(r)
  r.end()
  return tx
}

/** The transaction hash nodes report: `sha256(borsh(tx))`, hex. */
export const transactionHash = (tx: PublicTransaction): string =>
  toHex(sha256(encodeTransaction(tx)))

/** `sendTransaction`'s parameter: base64 of `LeeTransaction::Public` (tag 0) + the tx. */
export const sendTransactionParam = (tx: PublicTransaction): string =>
  toBase64(concat(new Uint8Array([0]), encodeTransaction(tx)))

/** Whether two messages are the same bytes. */
export const sameMessage = (a: PublicMessage, b: PublicMessage): boolean =>
  equal(encodeMessage(a), encodeMessage(b))
