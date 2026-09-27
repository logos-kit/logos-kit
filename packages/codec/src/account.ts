// LEZ 0.3 account ids: base58 of 32 bytes.
import { type Bytes, concat, fromBase58, toBase58, utf8 } from './bytes.ts'
import { sha256 } from './sha256.ts'

/** Base58 account id. */
export type AccountId = string

export function accountBytes(id: AccountId): Bytes {
  const b = fromBase58(id)
  if (b.length !== 32) throw new Error(`account id must be 32 bytes: ${id}`)
  return b
}

export function isAccountId(s: string): boolean {
  try {
    accountBytes(s)
    return true
  } catch {
    return false
  }
}

const pad32 = (s: string): Bytes => {
  const b = new Uint8Array(32)
  b.set(utf8(s))
  return b
}

const PUBLIC_PREFIX = pad32('/LEE/v0.3/AccountId/Public/')
const PDA_PREFIX = pad32('/LEE/v0.2/AccountId/PDA/')
const BUILTIN_PREFIX = utf8('/LEE-BuiltinProgram/v1/AccountId')

/** The account a BIP-340 x-only public key controls. */
export const publicAccountId = (publicKey: Bytes): AccountId => {
  if (publicKey.length !== 32) throw new Error('x-only public key must be 32 bytes')
  return toBase58(sha256(concat(PUBLIC_PREFIX, publicKey)))
}

/** A program's public PDA for a 32-byte seed. */
export const publicPda = (program: AccountId, seed: Bytes): AccountId => {
  if (seed.length !== 32) throw new Error('PDA seed must be 32 bytes')
  return toBase58(sha256(concat(PDA_PREFIX, accountBytes(program), seed)))
}

/** A builtin program's address, from its name. */
export const builtinProgram = (name: string): AccountId =>
  toBase58(sha256(concat(BUILTIN_PREFIX, utf8(name))))

/** The native token (and account balances) live at the all-zero id. */
export const NATIVE_TOKEN_PROGRAM: AccountId = toBase58(new Uint8Array(32))
export const TOKEN_PROGRAM: AccountId = builtinProgram('token')
export const ATA_PROGRAM: AccountId = builtinProgram('associated_token_account')
/** The program loader's dispatch address (`[0xFE; 32]`). */
export const PROGRAM_LOADER: AccountId = toBase58(new Uint8Array(32).fill(0xfe))

/** One program's slot ("shard") of an account. */
export interface ShardSelector {
  account: AccountId
  program: AccountId
}
