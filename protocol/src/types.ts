// Public TypeScript types, inferred from the TypeBox schemas (the single source
// of truth). Type-only imports: no TypeBox code reaches the runtime entry.
import type { Static } from 'typebox'
import type * as M from './schema/messaging.ts'
import type * as Mt from './schema/methods.ts'
import type * as P from './schema/primitives.ts'
import type * as S from './schema/session.ts'
import type * as T from './schema/transaction.ts'

export type ChainId = Static<typeof P.ChainId>
export type AccountId = Static<typeof P.AccountId>
export type PrivateHandle = Static<typeof P.PrivateHandle>
export type AccountKind = Static<typeof P.AccountKind>
export type U128 = Static<typeof P.U128>

export type Capability = Static<typeof S.Capability>
export type WalletAccount = Static<typeof S.WalletAccount>
export type Capabilities = Static<typeof S.Capabilities>
export type ConnectParams = Static<typeof S.ConnectParams>
export type Session = Static<typeof S.Session>
export type SignInRequest = Static<typeof S.SignInRequest>
export type SignInResult = Static<typeof S.SignInResult>

export type Instruction = Static<typeof T.Instruction>
export type TransactionProposal = Static<typeof T.TransactionProposal>
export type SubmitResult = Static<typeof T.SubmitResult>
export type Lifecycle = Static<typeof T.Lifecycle>
export type Outcome = Static<typeof T.Outcome>
export type OutcomeSource = Static<typeof T.OutcomeSource>
export type Effect = Static<typeof T.Effect>
export type FeeInfo = Static<typeof T.FeeInfo>
export type TransactionStatus = Static<typeof T.TransactionStatus>

export type SignMessageParams = Static<typeof M.SignMessageParams>
export type SignMessageResult = Static<typeof M.SignMessageResult>
export type RequestFundsParams = Static<typeof M.RequestFundsParams>
export type RequestFundsResult = Static<typeof M.RequestFundsResult>
export type BalanceParams = Static<typeof M.BalanceParams>
export type BalanceResult = Static<typeof M.BalanceResult>

export type MethodName = Mt.MethodName
export type NotificationName = Mt.NotificationName

/** Typed JSON-RPC schema: `LwsRpcSchema['lez_connect']['params']` etc. */
export type LwsRpcSchema = {
  [K in Mt.MethodName]: {
    params: Static<(typeof Mt.Methods)[K]['params']>
    result: Static<(typeof Mt.Methods)[K]['result']>
  }
}

export type LwsNotificationSchema = {
  [K in Mt.NotificationName]: Static<(typeof Mt.Notifications)[K]>
}
