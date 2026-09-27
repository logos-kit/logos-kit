// Reads and raw submission against a LEZ node (sequencer JSON-RPC).
import {
  type AccountId,
  accountBytes,
  type PublicTransaction,
  Reader,
  sendTransactionParam,
  TESTIMONIAL_PAGE_SIZE,
  TESTIMONIAL_SUBMISSION,
  testimonialStats,
  transactionHash,
} from '@logos-kit/codec'
import type { Client } from '../client.ts'
import {
  type Account,
  type Block,
  decodeAccount,
  decodeBlock,
  decodeTransactionResult,
  nativeBalance,
  type TransactionEnvelope,
} from '../decode.ts'
import { RpcError } from '../errors.ts'
import { decimal } from '../json.ts'
import { type PollOptions, pollValue } from '../poll.ts'

export interface FeeState {
  height: string
  baseFeeExec: string
  baseFeeStor: string
  nextBaseFeeExecCeiling: string
  nextBaseFeeStorCeiling: string
  maxGasExec: string
  maxGasStor: string
}

export interface NodeActions {
  getBlockNumber(): Promise<string>
  getBlock(id: string | number): Promise<Block | null>
  getAccount(account: AccountId): Promise<Account>
  /** One program's shard of an account (plus its nonce). */
  getAccountView(account: AccountId, program: AccountId): Promise<Account>
  getBalance(account: AccountId): Promise<string>
  getNonces(accounts: AccountId[]): Promise<string[]>
  getFeeState(): Promise<FeeState>
  getTransaction(hash: string): Promise<TransactionEnvelope | null>
  /**
   * Submit a signed public transaction; resolves to its hash (hex), computed
   * here. Never retried: see `http`.
   */
  sendRawTransaction(tx: PublicTransaction): Promise<string>
  /** Poll until the node reports the transaction in a block. */
  waitForTransaction(hash: string, options?: PollOptions): Promise<TransactionEnvelope>
  /** The testimonial program's first stats page that isn't full, and the total so far. */
  getTestimonialPage(
    program: AccountId,
    submission?: string,
  ): Promise<{ page: number; count: number }>
}

const HEX32 = /^[0-9a-f]{64}$/

export function nodeActions(client: Client): NodeActions {
  const self: NodeActions = {
    getBlockNumber: async () => decimal(await client.request('getLastBlockId', []), 'u64'),
    async getBlock(id) {
      const n = Number(decimal(id, 'u64'))
      if (!Number.isSafeInteger(n)) throw new RangeError(`block id too large: ${id}`)
      const v = await client.request<string | null>('getBlock', [n])
      return v === null ? null : decodeBlock(v)
    },
    getAccount: async (account) => {
      accountBytes(account)
      return decodeAccount(await client.request('getAccount', [account]))
    },
    getAccountView: async (account, program) => {
      accountBytes(account)
      accountBytes(program)
      return decodeAccount(
        await client.request('getAccountView', [
          { account_id: account, program_account_id: program },
        ]),
      )
    },
    getBalance: async (account) => {
      accountBytes(account)
      return decimal(await client.request('getAccountBalance', [account]))
    },
    getNonces: async (accounts) => {
      for (const a of accounts) accountBytes(a)
      const v = await client.request<unknown[]>('getAccountsNonces', [accounts])
      if (!Array.isArray(v) || v.length !== accounts.length) {
        throw new RpcError(-32603, 'the node answered the wrong number of nonces')
      }
      return v.map((n) => decimal(n))
    },
    async getFeeState() {
      const f = await client.request<Record<string, unknown>>('getFeeState', [])
      return {
        height: decimal(f.height, 'u64'),
        baseFeeExec: decimal(f.base_fee_exec, 'u64'),
        baseFeeStor: decimal(f.base_fee_stor, 'u64'),
        nextBaseFeeExecCeiling: decimal(f.next_base_fee_exec_ceiling, 'u64'),
        nextBaseFeeStorCeiling: decimal(f.next_base_fee_stor_ceiling, 'u64'),
        maxGasExec: decimal(f.max_gas_exec, 'u64'),
        maxGasStor: decimal(f.max_gas_stor, 'u64'),
      }
    },
    async getTransaction(hash) {
      if (!HEX32.test(hash)) throw new Error('transaction hash must be 64 lowercase hex characters')
      return decodeTransactionResult(await client.request('getTransaction', [hash]))
    },
    async sendRawTransaction(tx) {
      // The hash is ours to compute; a node answering another one is wrong.
      const hash = transactionHash(tx)
      const v = await client.request<unknown>('sendTransaction', [sendTransactionParam(tx)])
      if (typeof v === 'string' && v.toLowerCase() !== hash) {
        throw new RpcError(-32603, `the node answered hash ${v} for transaction ${hash}`)
      }
      return hash
    },
    waitForTransaction: (hash, options) =>
      pollValue(
        async () => (await self.getTransaction(hash)) ?? undefined,
        `transaction ${hash}`,
        options,
      ),
    getTestimonialPage: (program, submission = TESTIMONIAL_SUBMISSION) =>
      openTestimonialPage(
        program,
        submission,
        async (stats) => (await self.getAccountView(stats, program)).shards[program],
      ),
  }
  return self
}

/** Authors on a testimonial stats page (`testimonial_core::Stats`). */
export function statsAuthors(b: Uint8Array | undefined): number {
  if (!b || b.length === 0) return 0
  const r = new Reader(b)
  r.u8() // version
  r.string() // submission
  r.u32() // page
  r.u64() // first_ms
  r.u64() // last_ms
  r.vec((r) => [r.u32(), r.u32()]) // monthly
  return r.u32() // authors.len()
}

/** Pages a submission can have before we stop believing the node (10 M posts). */
const MAX_PAGES = 10000

/** Walk stats pages (read with `read`) to the first one that isn't full. */
export async function openTestimonialPage(
  program: AccountId,
  submission: string,
  read: (stats: AccountId) => Promise<Uint8Array | undefined>,
): Promise<{ page: number; count: number }> {
  let count = 0
  for (let page = 0; page < MAX_PAGES; page++) {
    const n = statsAuthors(await read(testimonialStats(program, submission, page)))
    count += n
    if (n < TESTIMONIAL_PAGE_SIZE) return { page, count }
  }
  throw new RangeError('more testimonial pages than a submission can hold')
}

export { nativeBalance }
