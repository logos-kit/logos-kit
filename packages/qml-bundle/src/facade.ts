// `createLogosKit`: the Logos Kit SDK for Basecamp QML apps.
//
// User-facing steps (connect, send, sign, sign in, faucet) are Basecamp
// intents: the shell shows its chooser, then our wallet's own sheet. Reads and
// status go straight to the wallet core module. Keys never leave the wallet.
// Names match @logos-kit/client's walletActions, so code ports both ways.
import {
  basecampModule,
  type CallModuleAsync,
  createClient,
  FINAL_LIFECYCLES,
  type PollOptions,
  poll,
  resolveTestimonial,
  type TestimonialRequest,
  toInstruction,
  walletActions,
} from '@logos-kit/client'
import { type AccountId, nativeTransfer, type ProgramCall, tokenTransfer } from '@logos-kit/codec'
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
  /**
   * A user-facing step rejects with `Timeout` after this long (default 45 s).
   * The wallet may still be showing it: a timeout does NOT mean nothing was
   * sent. The busy guard stays closed until the wallet really answers, and
   * that late answer goes to `onLateResult`.
   */
  intentTimeoutMs?: number
  /** The real answer to a step that already timed out (e.g. a send's handle). */
  onLateResult?: (intent: string, ok: boolean, data: unknown) => void
  /** Status polling pauses while this returns false (e.g. the view is hidden). */
  isVisible?: () => boolean
}

export interface WatchHandle {
  stop(): void
}

export interface LogosKit {
  readonly chain: ChainId
  /** A user-facing step is open (connect, send, sign…); another one is refused. */
  isBusy(): boolean
  connect(params?: Partial<ConnectParams>): Promise<Session>
  getSession(sessionId?: string): Promise<Session | null>
  getAccounts(): Promise<WalletAccount[]>
  /** Native balance, or a token's with `asset`. */
  getWalletBalance(account: AccountId, asset?: AccountId): Promise<BalanceResult>
  /** A public account's data for one program (chain state). */
  readAccount(account: AccountId, program: AccountId): Promise<{ nonce: string; data: Uint8Array }>
  /**
   * Answers once the user approved (with a handle), before the transaction
   * lands. An `id` is added if missing, so the wallet can refuse a duplicate.
   */
  sendTransaction(
    proposal: Omit<TransactionProposal, 'chain'> & { chain?: ChainId },
  ): Promise<SubmitResult>
  sendCall(account: AccountId, call: ProgramCall): Promise<SubmitResult>
  transfer(from: AccountId, to: AccountId, amount: string, token?: AccountId): Promise<SubmitResult>
  /** Finds the open stats page itself when `page` is omitted. */
  postTestimonial(post: TestimonialRequest): Promise<SubmitResult>
  getTransactionStatus(handle: string): Promise<TransactionStatus>
  /** Calls `onUpdate` on every status change until the lifecycle is final. */
  watchTransaction(
    handle: string,
    onUpdate: (s: TransactionStatus) => void,
    onError?: (e: unknown) => void,
    options?: PollOptions,
  ): WatchHandle
  waitForTransactionStatus(handle: string, options?: PollOptions): Promise<TransactionStatus>
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

let ids = 0
/** A proposal id unique per app session (LWS-0 `id`; the wallet refuses a repeat). */
const newId = (): string => `lk-${Date.now().toString(36)}-${(++ids).toString(36)}`

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
      let timedOut = false
      let answered = false
      const timer = setTimeout(() => {
        timedOut = true
        reject(
          new LezError(
            ErrorCode.Timeout,
            'The wallet has not answered yet; it may still send. Wait for it before trying again.',
          ),
        )
      }, timeout)
      const answer = (ok: boolean, data: unknown, error: unknown) => {
        if (answered) return
        answered = true
        busy = false
        clearTimeout(timer)
        if (timedOut) {
          if (host.onLateResult) host.onLateResult(name, ok, ok ? data : intentError(error))
        } else if (ok) resolve(data as T)
        else reject(intentError(error))
      }
      try {
        host.openIntent(name, params, (res) => answer(!!res?.ok, res?.data, res?.error))
      } catch (e) {
        answer(false, undefined, e)
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
    getWalletBalance: (account, asset) =>
      wallet.getWalletBalance(asset ? { chain, account, asset } : { chain, account }),
    readAccount: (account, program) => wallet.readAccount(account, program),
    sendTransaction: (proposal) =>
      intent<SubmitResult>(INTENTS.sendTransaction, {
        ...proposal,
        chain: proposal.chain || chain,
        id: proposal.id || newId(),
      }),
    sendCall: (account, call) =>
      kit.sendTransaction({ account, instructions: [toInstruction(call)] }),
    transfer: (from, to, amount, token) =>
      kit.sendCall(
        from,
        token ? tokenTransfer(from, to, token, amount) : nativeTransfer(from, to, amount),
      ),
    postTestimonial: async (post) =>
      kit.sendCall(post.author, await resolveTestimonial(post, wallet.readAccount)),
    getTransactionStatus: (handle) => wallet.getTransactionStatus(handle),
    watchTransaction(handle, onUpdate, onError, options) {
      let stopped = false
      let last = ''
      const o = withVisibility(options)
      o.shouldStop = () => stopped
      poll(
        async () => {
          const s = await wallet.getTransactionStatus(handle)
          const key = `${s.lifecycle}|${s.outcome}|${s.proving ? s.proving.phase : ''}`
          if (!stopped && key !== last) {
            last = key
            onUpdate(s)
          }
          return FINAL_LIFECYCLES.indexOf(s.lifecycle) >= 0 ? s : undefined
        },
        `transaction ${handle}`,
        o,
      ).catch((e) => {
        if (!stopped && onError) onError(e)
      })
      return {
        stop() {
          stopped = true
        },
      }
    },
    waitForTransactionStatus: (handle, options) =>
      wallet.waitForTransactionStatus(handle, withVisibility(options)),
    signMessage: (account, message) =>
      intent<SignMessageResult>(INTENTS.signMessage, { account, message }),
    signIn: (request) => intent<SignInResult>(INTENTS.signIn, request),
    requestFunds: (account) => intent<RequestFundsResult>(INTENTS.requestFunds, { chain, account }),
  }
  return kit
}
