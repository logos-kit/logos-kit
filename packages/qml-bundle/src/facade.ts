// `createLogosKit`: the Logos Kit SDK for Basecamp QML apps.
//
// User-facing steps (connect, send, sign, sign in, faucet) are Basecamp
// intents: the shell shows its chooser, then our wallet's own sheet. Reads and
// status go straight to the wallet core module. Keys never leave the wallet.
import {
  basecampModule,
  type CallModuleAsync,
  createClient,
  FINAL_LIFECYCLES,
  type PollOptions,
  poll,
  toInstruction,
  walletActions,
} from '@logos-kit/client'
import {
  type AccountId,
  nativeTransfer,
  type ProgramCall,
  type TestimonialPost,
  testimonialPost,
  tokenTransfer,
} from '@logos-kit/codec'
import {
  type BalanceResult,
  CHAINS,
  type ChainId,
  type ConnectParams,
  ErrorCode,
  fromIntentError,
  INTENTS,
  LezError,
  type RequestFundsResult,
  type Session,
  type SignInRequest,
  type SignInResult,
  type SignMessageResult,
  type SubmitResult,
  type TransactionProposal,
  type TransactionStatus,
  type WalletAccount,
} from '@logos-kit/protocol'

/** Basecamp's `logos.request(intent, params, callback)`. */
export type OpenIntent = (
  intent: string,
  params: unknown,
  callback: (res: { ok: boolean; data?: unknown; error?: unknown }) => void,
) => void

export interface LogosKitHost {
  callModuleAsync: CallModuleAsync
  openIntent: OpenIntent
  /** Default `lez:testnet`. */
  chain?: ChainId
  /** Wallet core module (default `logos_kit_wallet`). */
  module?: string
  /** A user-facing step fails with `Timeout` after this long. Default 45 s. */
  intentTimeoutMs?: number
  /** Status polling pauses while this returns false (e.g. the view is hidden). */
  isVisible?: () => boolean
}

export interface WatchHandle {
  stop(): void
}

export interface LogosKit {
  readonly chain: ChainId
  /** A user-facing step is open (connect, send, sign…); a second one is refused. */
  isBusy(): boolean
  connect(params?: Partial<ConnectParams>): Promise<Session>
  getSession(sessionId?: string): Promise<Session | null>
  getAccounts(): Promise<WalletAccount[]>
  /** Native balance, or a token's with `token`. Decimal string. */
  getBalance(account: AccountId, token?: AccountId): Promise<BalanceResult>
  /** Answers once the user approved (with a handle), before the transaction lands. */
  sendTransaction(
    proposal: Omit<TransactionProposal, 'chain'> & { chain?: ChainId },
  ): Promise<SubmitResult>
  sendCall(account: AccountId, call: ProgramCall): Promise<SubmitResult>
  transfer(from: AccountId, to: AccountId, amount: string, token?: AccountId): Promise<SubmitResult>
  postTestimonial(
    post: Omit<TestimonialPost, 'timestampMs'> & { timestampMs?: number },
  ): Promise<SubmitResult>
  getTransactionStatus(handle: string): Promise<TransactionStatus>
  /** Calls `onUpdate` on every status change until the lifecycle is final. */
  watchTransaction(
    handle: string,
    onUpdate: (s: TransactionStatus) => void,
    onError?: (e: unknown) => void,
    options?: PollOptions,
  ): WatchHandle
  waitForTransaction(handle: string, options?: PollOptions): Promise<TransactionStatus>
  signMessage(account: AccountId, message: string): Promise<SignMessageResult>
  signIn(request: SignInRequest): Promise<SignInResult>
  requestFunds(account: AccountId): Promise<RequestFundsResult>
}

function intentError(e: unknown): LezError {
  if (e instanceof LezError) return e
  if (typeof e === 'string') return fromIntentError(e)
  const o = e as { code?: unknown; message?: unknown; data?: unknown } | null
  if (o && typeof o.code === 'number') return new LezError(o.code, String(o.message || ''), o.data)
  if (o && typeof o.code === 'string') return fromIntentError(o.code)
  return new LezError(ErrorCode.Internal, 'Wallet request failed')
}

export function createLogosKit(host: LogosKitHost): LogosKit {
  const chain = host.chain || CHAINS.lezTestnet
  const timeout = host.intentTimeoutMs || 45000
  const wallet = createClient({
    transport: basecampModule({ callModuleAsync: host.callModuleAsync, module: host.module }),
    chain,
  }).extend(walletActions)
  let busy = false

  function intent<T>(name: string, params: unknown): Promise<T> {
    if (busy) {
      return Promise.reject(
        new LezError(ErrorCode.RequestPending, 'Finish the open wallet request first'),
      )
    }
    busy = true
    return new Promise<T>((resolve, reject) => {
      let done = false
      const finish = (f: () => void) => {
        if (done) return
        done = true
        busy = false
        clearTimeout(timer)
        f()
      }
      const timer = setTimeout(
        () =>
          finish(() =>
            reject(new LezError(ErrorCode.Timeout, 'The wallet did not answer in time')),
          ),
        timeout,
      )
      try {
        host.openIntent(name, params, (res) =>
          finish(() => (res?.ok ? resolve(res.data as T) : reject(intentError(res?.error)))),
        )
      } catch (e) {
        finish(() => reject(intentError(e)))
      }
    })
  }

  const withVisibility = (o?: PollOptions): PollOptions => {
    const out: PollOptions = {}
    if (o)
      for (const k of Object.keys(o) as (keyof PollOptions)[])
        (out as Record<string, unknown>)[k] = o[k]
    if (!out.isVisible && host.isVisible) out.isVisible = host.isVisible
    return out
  }

  const kit: LogosKit = {
    chain,
    isBusy: () => busy,
    connect: (params) => intent<Session>(INTENTS.connect, { chains: [chain], ...params }),
    getSession: (sessionId) => wallet.getSession(sessionId),
    getAccounts: () => wallet.getAccounts(),
    getBalance: (account, token) =>
      wallet.getWalletBalance(
        token ? { chain, account, asset: token } : { chain, account },
      ) as Promise<BalanceResult>,
    sendTransaction: (proposal) =>
      intent<SubmitResult>(INTENTS.sendTransaction, {
        ...proposal,
        chain: proposal.chain || chain,
      }),
    sendCall: (account, call) =>
      kit.sendTransaction({ account, instructions: [toInstruction(call)] }),
    transfer: (from, to, amount, token) =>
      kit.sendCall(
        from,
        token ? tokenTransfer(from, to, token, amount) : nativeTransfer(from, to, amount),
      ),
    postTestimonial: (post) =>
      kit.sendCall(
        post.author,
        testimonialPost({ ...post, timestampMs: post.timestampMs || Date.now() }),
      ),
    getTransactionStatus: (handle) => wallet.getTransactionStatus(handle),
    watchTransaction(handle, onUpdate, onError, options) {
      let stopped = false
      let last = ''
      poll(
        async () => {
          if (stopped) return null
          const s = await wallet.getTransactionStatus(handle)
          const key = `${s.lifecycle}|${s.outcome}|${s.proving ? s.proving.phase : ''}`
          if (!stopped && key !== last) {
            last = key
            onUpdate(s)
          }
          return FINAL_LIFECYCLES.indexOf(s.lifecycle) >= 0 ? s : undefined
        },
        `transaction ${handle}`,
        withVisibility(options),
      ).catch((e) => {
        if (!stopped && onError) onError(e)
      })
      return {
        stop() {
          stopped = true
        },
      }
    },
    waitForTransaction: (handle, options) =>
      wallet.waitForTransactionStatus(handle, withVisibility(options)),
    signMessage: (account, message) =>
      intent<SignMessageResult>(INTENTS.signMessage, { account, message }),
    signIn: (request) => intent<SignInResult>(INTENTS.signIn, request),
    requestFunds: (account) => intent<RequestFundsResult>(INTENTS.requestFunds, { chain, account }),
  }
  return kit
}
