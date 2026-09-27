// @logos-kit/client/local: sign with a raw key held by the app (scripts,
// servers, tests). Not QML-safe (BIP-340 needs native BigInt). Wallet users
// should go through the wallet (walletActions) instead.
import {
  type AccountId,
  type Bytes,
  DEFAULT_GAS_LIMIT,
  defaultMaxFee,
  type FeeDeclaration,
  type ProgramCall,
  type PublicMessage,
  type PublicTransaction,
} from '@logos-kit/codec'
import { accountOf, signMessage } from '@logos-kit/codec/sign'
import type { NodeActions } from './actions/node.ts'

export interface LocalAccount {
  readonly type: 'local'
  readonly address: AccountId
  sign(message: PublicMessage): PublicTransaction
}

export function localAccount(secretKey: Bytes): LocalAccount {
  const key = secretKey.slice()
  return {
    type: 'local',
    address: accountOf(key),
    sign: (message) => signMessage(message, [key]),
  }
}

export interface LocalSendOptions {
  gasLimit?: string
  maxFee?: string
  tip?: string
}

/** Build, sign and submit `call` from a local account (it signs every signer row and pays). */
export async function sendCall(
  node: NodeActions,
  account: LocalAccount,
  call: ProgramCall,
  options: LocalSendOptions = {},
): Promise<string> {
  for (const row of call.accounts) {
    if (row.signer && row.account !== account.address)
      throw new Error(`${row.account} must sign, but this local account is ${account.address}`)
  }
  const [nonce] = await node.getNonces([account.address])
  const gasLimit = options.gasLimit ?? DEFAULT_GAS_LIMIT
  const fee: FeeDeclaration = {
    payer: account.address,
    gasLimit,
    tip: options.tip ?? '0',
    maxFee: options.maxFee ?? defaultMaxFee(gasLimit),
  }
  const message: PublicMessage = {
    program: call.program,
    shardSelectors: call.accounts.map((a) => ({ account: a.account, program: a.program })),
    nonces: [nonce as string],
    instructionData: call.data,
    fee,
  }
  return node.sendRawTransaction(account.sign(message))
}
