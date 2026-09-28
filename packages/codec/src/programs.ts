// Instruction builders for the programs dApps call most. Each returns the
// program, the account rows and the borsh data: exactly what LWS-0's
// `lez_signAndSendTransaction` takes, and what the wallet decodes back.
import {
  type AccountId,
  accountBytes,
  NATIVE_TOKEN_PROGRAM,
  publicPda,
  type ShardSelector,
  TOKEN_PROGRAM,
} from './account.ts'
import { Reader, Writer } from './borsh.ts'
import { type Bytes, concat, toBase58, utf8 } from './bytes.ts'
import { sha256 } from './sha256.ts'

export interface AccountRow extends ShardSelector {
  signer: boolean
  /** The call changes this row's data (shown on the approval sheet). */
  writable: boolean
}

export interface ProgramCall {
  program: AccountId
  accounts: AccountRow[]
  data: Bytes
}

/** Native transfer (`native_token::Instruction::Transfer`). `from` signs. */
export function nativeTransfer(from: AccountId, to: AccountId, amount: string): ProgramCall {
  return {
    program: NATIVE_TOKEN_PROGRAM,
    accounts: [
      { account: from, program: NATIVE_TOKEN_PROGRAM, signer: true, writable: true },
      { account: to, program: NATIVE_TOKEN_PROGRAM, signer: false, writable: true },
    ],
    data: new Writer().u8(0).u128(amount).toBytes(),
  }
}

export type TokenKind = 'fungible' | 'nft_master' | 'nft_copy'
const KIND: Record<TokenKind, number> = { fungible: 0, nft_master: 1, nft_copy: 2 }

/**
 * Token transfer between two accounts' own token slots (`token::Instruction::Transfer`).
 * `from` signs; `to`'s slot must be empty or hold the same token.
 */
export function tokenTransfer(
  from: AccountId,
  to: AccountId,
  definition: AccountId,
  amount: string,
  kind: TokenKind = 'fungible',
): ProgramCall {
  // Object.hasOwn is ES2022; these packages must run in Qt's ES2017 engine.
  if (!Object.prototype.hasOwnProperty.call(KIND, kind))
    throw new Error(`unknown token kind: ${kind}`)
  return {
    program: TOKEN_PROGRAM,
    accounts: [
      { account: from, program: TOKEN_PROGRAM, signer: true, writable: true },
      { account: to, program: TOKEN_PROGRAM, signer: false, writable: true },
    ],
    data: new Writer().u8(0).u128(amount).fixed(accountBytes(definition)).u8(KIND[kind]).toBytes(),
  }
}

// ---- Logos Kit testimonial program (programs/testimonial) ----

export const TESTIMONIAL_SUBMISSION = 'LP-0021/logos-kit'
export const TESTIMONIAL_PAGE_SIZE = 1000
/** Byte limits the program enforces (`testimonial_core`). */
export const TESTIMONIAL_MAX_TEXT = 280
export const TESTIMONIAL_MAX_USERNAME = 32
/**
 * The deployed testimonial program per chain (immutable deploys listed in
 * `registry/programs.json`). Missing until the chain has one.
 */
export const TESTIMONIAL_PROGRAMS: Readonly<Record<string, AccountId>> = {
  // Logos Kit preview network (LEZ 0.3-rc1), immutable, image 8308e67d…
  'lez:preview': '4vjENywUCfC3h85mjNGFPV7R9DqvUjV2xhMkCZbJR8XK' as AccountId,
}
const SEED_DOMAIN = utf8('logos-kit/testimonial/v1/')

function testimonialSeed(tag: string, submission: string, extra: Bytes): Bytes {
  const sub = utf8(submission)
  if (sub.length < 1 || sub.length > 32) throw new Error('submission id must be 1-32 bytes')
  return sha256(concat(SEED_DOMAIN, utf8(tag), new Uint8Array([0, sub.length]), sub, extra))
}

const le32 = (n: number): Bytes => new Writer().u32(n).toBytes()

export const testimonialStats = (program: AccountId, submission: string, page: number): AccountId =>
  publicPda(program, testimonialSeed('stats', submission, le32(page)))

export const testimonialRecord = (
  program: AccountId,
  submission: string,
  author: AccountId,
): AccountId => publicPda(program, testimonialSeed('record', submission, accountBytes(author)))

export interface TestimonialPost {
  program: AccountId
  author: AccountId
  text: string
  username?: string
  submission?: string
  /** First stats page that isn't full (read it with the client's `getTestimonialPage`). */
  page?: number
  /** Unix ms; the chain accepts a block within −2 min / +10 min of it. */
  timestampMs: number
}

/** A post to the testimonial program. The author signs and pays; it must be public. */
export function testimonialPost(p: TestimonialPost): ProgramCall {
  const submission = p.submission ?? TESTIMONIAL_SUBMISSION
  const page = p.page ?? 0
  const row = (account: AccountId, signer: boolean, writable: boolean): AccountRow => ({
    account,
    program: p.program,
    signer,
    writable,
  })
  const accounts = [
    row(p.author, true, false),
    row(testimonialStats(p.program, submission, page), false, true),
    row(testimonialRecord(p.program, submission, p.author), false, true),
  ]
  if (page > 0) accounts.push(row(testimonialStats(p.program, submission, page - 1), false, false))
  const data = new Writer()
    .u8(0)
    .string(submission)
    .u32(page)
    .option(p.username, (w, u) => {
      w.string(u)
    })
    .string(p.text)
    .u64(String(p.timestampMs))
    .toBytes()
  return { program: p.program, accounts, data }
}

/** A stored testimonial (`testimonial_core::Testimonial`). */
export interface Testimonial {
  submission: string
  author: AccountId
  username: string | null
  text: string
  timestampMs: number
}

/** A testimonial stats page (`testimonial_core::Stats`). */
export interface TestimonialStats {
  page: number
  firstMs: number
  lastMs: number
  /** Posts per UTC month, ascending: `yyyymm` like 202611. */
  monthly: { yyyymm: number; count: number }[]
  /** Authors in posting order. */
  authors: AccountId[]
}

const ms = (r: Reader): number => Number(r.u64())

/** Decode a record shard; `null` when the author hasn't posted. */
export function decodeTestimonial(b: Bytes | undefined): Testimonial | null {
  if (!b || b.length === 0) return null
  const r = new Reader(b)
  if (r.u8() !== 1) throw new Error('testimonial: unknown record version')
  const t: Testimonial = {
    submission: r.string(),
    author: toBase58(r.fixed(32)),
    username: r.option((r) => r.string()),
    text: r.string(),
    timestampMs: ms(r),
  }
  r.end()
  return t
}

/** Decode a stats page shard; `null` when the page hasn't opened. */
export function decodeTestimonialStats(b: Bytes | undefined): TestimonialStats | null {
  if (!b || b.length === 0) return null
  const r = new Reader(b)
  if (r.u8() !== 1) throw new Error('testimonial: unknown stats version')
  r.string() // submission
  const s: TestimonialStats = {
    page: r.u32(),
    firstMs: ms(r),
    lastMs: ms(r),
    monthly: r.vec((r) => ({ yyyymm: r.u32(), count: r.u32() })),
    authors: r.vec((r) => toBase58(r.fixed(32))),
  }
  r.end()
  return s
}
