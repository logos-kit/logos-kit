// LWS-0: what a dApp asks of the Logos Kit wallet. The client's transport
// must speak LWS-0 (basecampModule, or a provider via `custom`).
import {
  type AccountId,
  type ProgramCall,
  type TestimonialPost,
  testimonialPost,
  toBase64,
} from '@logos-kit/codec'
import {
  type ConnectParams,
  type LwsRpcSchema,
  METHODS,
  type RequestFundsResult,
  type Session,
  type SignInResult,
  type SignMessageResult,
  type SubmitResult,
  type TransactionProposal,
  type TransactionStatus,
  type WalletAccount,
} from '@logos-kit/protocol'
import type { Client } from '../client.ts'
import { type PollOptions, poll } from '../poll.ts'

type P<K extends keyof LwsRpcSchema> = LwsRpcSchema[K]['params']

/** Lifecycles after which a transaction's status won't change. */
export const FINAL_LIFECYCLES: readonly string[] = [
  'included',
  'finalized',
  'rejected',
  'dropped',
  'expired',
]

export interface WalletActions {
  connect(params: ConnectParams): Promise<Session>
  disconnect(sessionId: string): Promise<null>
  getSession(sessionId?: string): Promise<Session | null>
  getAccounts(): Promise<WalletAccount[]>
  getWalletBalance(params: P<'lez_getBalance'>): Promise<LwsRpcSchema['lez_getBalance']['result']>
  /** Propose; resolves once the wallet queued it (`handle`), before approval finishes. */
  sendTransaction(proposal: TransactionProposal): Promise<SubmitResult>
  /** One program call from `account` (built with @logos-kit/codec). */
  sendCall(account: AccountId, call: ProgramCall): Promise<SubmitResult>
  getTransactionStatus(handle: string): Promise<TransactionStatus>
  /** Poll a handle until its lifecycle is final. */
  waitForTransactionStatus(handle: string, options?: PollOptions): Promise<TransactionStatus>
  signMessage(params: P<'lez_signMessage'>): Promise<SignMessageResult>
  signIn(params: P<'lez_signIn'>): Promise<SignInResult>
  requestFunds(params: P<'lez_requestFunds'>): Promise<RequestFundsResult>
  switchChain(params: P<'lez_switchChain'>): Promise<LwsRpcSchema['lez_switchChain']['result']>
  /** Post to the testimonial program from a public account (it signs and pays). */
  postTestimonial(
    post: Omit<TestimonialPost, 'timestampMs'> & { timestampMs?: number },
  ): Promise<SubmitResult>
}

/** A codec program call as an LWS-0 proposal instruction. */
export function toInstruction(call: ProgramCall): TransactionProposal['instructions'][number] {
  return {
    program: call.program,
    accounts: call.accounts.map((a) => ({ account: a.account, writable: true, signer: a.signer })),
    data: toBase64(call.data),
  }
}

export function walletActions(client: Client): WalletActions {
  const call = <K extends keyof LwsRpcSchema>(method: K, params: P<K>) =>
    client.request<LwsRpcSchema[K]['result']>(method, params)
  const self: WalletActions = {
    connect: (params) => call(METHODS.connect, params) as Promise<Session>,
    disconnect: (sessionId) => call(METHODS.disconnect, { sessionId }) as Promise<null>,
    getSession: (sessionId) =>
      call(
        METHODS.getSession,
        sessionId === undefined ? {} : { sessionId },
      ) as Promise<Session | null>,
    getAccounts: () => call(METHODS.getAccounts, {}) as Promise<WalletAccount[]>,
    getWalletBalance: (params) => call(METHODS.getBalance, params),
    sendTransaction: (proposal) =>
      call(METHODS.signAndSendTransaction, proposal) as Promise<SubmitResult>,
    sendCall: (account, c) =>
      self.sendTransaction({ chain: client.chain, account, instructions: [toInstruction(c)] }),
    getTransactionStatus: (handle) =>
      call(METHODS.getTransactionStatus, { handle }) as Promise<TransactionStatus>,
    waitForTransactionStatus: (handle, options) =>
      poll(
        async () => {
          const s = await self.getTransactionStatus(handle)
          return FINAL_LIFECYCLES.indexOf(s.lifecycle) >= 0 ? s : undefined
        },
        `transaction ${handle}`,
        options,
      ),
    signMessage: (params) => call(METHODS.signMessage, params) as Promise<SignMessageResult>,
    signIn: (params) => call(METHODS.signIn, params) as Promise<SignInResult>,
    requestFunds: (params) => call(METHODS.requestFunds, params) as Promise<RequestFundsResult>,
    switchChain: (params) => call(METHODS.switchChain, params),
    postTestimonial: (post) =>
      self.sendCall(
        post.author,
        testimonialPost({ ...post, timestampMs: post.timestampMs ?? Date.now() }),
      ),
  }
  return self
}
