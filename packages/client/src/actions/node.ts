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
  toHex,
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
import { decimal } from '../json.ts'
import { type PollOptions, poll } from '../poll.ts'

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
  /** Submit a signed public transaction; resolves to its hash (hex). */
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
    getBlockNumber: async () => decimal(await client.request('getLastBlockId', [])),
    async getBlock(id) {
      const v = await client.request<string | null>('getBlock', [Number(decimal(id))])
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
      return v.map(decimal)
    },
    async getFeeState() {
      const f = await client.request<Record<string, unknown>>('getFeeState', [])
      return {
        height: decimal(f.height),
        baseFeeExec: decimal(f.base_fee_exec),
        baseFeeStor: decimal(f.base_fee_stor),
        nextBaseFeeExecCeiling: decimal(f.next_base_fee_exec_ceiling),
        nextBaseFeeStorCeiling: decimal(f.next_base_fee_stor_ceiling),
        maxGasExec: decimal(f.max_gas_exec),
        maxGasStor: decimal(f.max_gas_stor),
      }
    },
    async getTransaction(hash) {
      if (!HEX32.test(hash)) throw new Error('transaction hash must be 64 lowercase hex characters')
      return decodeTransactionResult(await client.request('getTransaction', [hash]))
    },
    async sendRawTransaction(tx) {
      const v = await client.request<unknown>('sendTransaction', [sendTransactionParam(tx)])
      return typeof v === 'string' ? v : toHex(new Uint8Array(v as number[]))
    },
    waitForTransaction: (hash, options) =>
      poll(
        async () => (await self.getTransaction(hash)) ?? undefined,
        `transaction ${hash}`,
        options,
      ),
    async getTestimonialPage(program, submission = TESTIMONIAL_SUBMISSION) {
      let count = 0
      for (let page = 0; ; page++) {
        const account = await self.getAccountView(
          testimonialStats(program, submission, page),
          program,
        )
        const n = statsAuthors(account.shards[program])
        count += n
        if (n < TESTIMONIAL_PAGE_SIZE) return { page, count }
      }
    },
  }
  return self
}

/** Authors on a testimonial stats page (`testimonial_core::Stats`). */
function statsAuthors(b: Uint8Array | undefined): number {
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

export { nativeBalance }
