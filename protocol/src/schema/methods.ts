import Type from 'typebox'
import {
  BalanceParams,
  BalanceResult,
  OpenExplorerParams,
  OpenExplorerResult,
  ReadAccountParams,
  ReadAccountResult,
  RequestFundsParams,
  RequestFundsResult,
  SignMessageParams,
  SignMessageResult,
} from './messaging.ts'
import { AccountId, ChainId, PrivateHandle } from './primitives.ts'
import {
  Capabilities,
  ConnectParams,
  Session,
  SignInRequest,
  SignInResult,
  WalletAccount,
} from './session.ts'
import { SubmitResult, TransactionProposal, TransactionStatus } from './transaction.ts'

const Empty = Type.Object({})
const Null = Type.Null()

/**
 * LWS-0 method table. Every surface (Basecamp intents + module calls, browser
 * postMessage, React Native in-process, pairing relay) carries exactly these
 * methods. `userFacing` methods may show wallet UI; the rest never do.
 */
export const Methods = {
  lez_connect: { params: ConnectParams, result: Session, userFacing: true },
  lez_disconnect: {
    params: Type.Object({ sessionId: Type.String() }),
    result: Null,
    userFacing: false,
  },
  lez_getSession: {
    params: Type.Object({ sessionId: Type.Optional(Type.String()) }),
    result: Type.Union([Session, Null]),
    userFacing: false,
  },
  lez_getAccounts: { params: Empty, result: Type.Array(WalletAccount), userFacing: false },
  lez_getCapabilities: {
    params: Type.Object({ chain: Type.Optional(ChainId) }),
    result: Capabilities,
    userFacing: false,
  },
  lez_getBalance: { params: BalanceParams, result: BalanceResult, userFacing: false },
  /** Read one program's public data on an account (chain state: no grant needed). */
  lez_readAccount: { params: ReadAccountParams, result: ReadAccountResult, userFacing: false },
  /** Open the zone's explorer at a transaction or account (the wallet builds the URL). */
  lez_openExplorer: { params: OpenExplorerParams, result: OpenExplorerResult, userFacing: false },
  lez_signAndSendTransaction: {
    params: TransactionProposal,
    result: SubmitResult,
    userFacing: true,
  },
  lez_getTransactionStatus: {
    params: Type.Object({ handle: Type.String() }),
    result: TransactionStatus,
    userFacing: false,
  },
  lez_signMessage: { params: SignMessageParams, result: SignMessageResult, userFacing: true },
  lez_signIn: {
    params: Type.Intersect([
      SignInRequest,
      Type.Object({ account: Type.Optional(Type.Union([AccountId, PrivateHandle])) }),
    ]),
    result: SignInResult,
    userFacing: true,
  },
  lez_requestFunds: { params: RequestFundsParams, result: RequestFundsResult, userFacing: true },
  lez_switchChain: { params: Type.Object({ chain: ChainId }), result: Null, userFacing: true },
} as const

export type MethodName = keyof typeof Methods

/** Push notifications (JSON-RPC notifications, no id). Payloads carry no private data. */
export const Notifications = {
  lez_accountsChanged: Type.Array(WalletAccount),
  lez_chainChanged: ChainId,
  lez_sessionChanged: Type.Union([Session, Null]),
  lez_disconnected: Type.Object({ code: Type.Integer(), message: Type.String() }),
  /** Handle-only: fetch details with lez_getTransactionStatus (caller-gated). */
  lez_transactionUpdated: Type.Object({ handle: Type.String() }),
  lez_capabilitiesChanged: Capabilities,
} as const

export type NotificationName = keyof typeof Notifications
