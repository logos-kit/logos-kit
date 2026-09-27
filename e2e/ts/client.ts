// S6 exit proof: @logos-kit/client + codec against a live LEZ 0.3 sequencer
// (e2e/standalone.sh). A native transfer built, signed (BIP-340, ./local) and
// submitted entirely in TypeScript must land and move the balance.

import { createClient, http, nodeActions } from '../../packages/client/src/index.ts'
import { localAccount, sendLocalCall } from '../../packages/client/src/local.ts'
import { fromHex, nativeTransfer, transactionHash } from '../../packages/codec/src/index.ts'
import { accountOf } from '../../packages/codec/src/sign.ts'

const url = process.env.LK_E2E_SEQUENCER ?? 'http://127.0.0.1:3040'
const node = createClient({ transport: http(url), chain: 'lez:local' }).extend(nodeActions)
// LEZ debug genesis key (vendor/lez/Justfile `wallet-import-test-accounts`).
const genesis = localAccount(
  fromHex('7f273098f25b71e6c005a9519f2678da8d1c7f01f6a27778e2d9948abdf901fb'),
)
const to = accountOf(crypto.getRandomValues(new Uint8Array(32)).fill(7, 0, 1))

const check = (what: string, got: unknown, want: unknown) => {
  if (got !== want) throw new Error(`FAIL ${what}: got ${got}, want ${want}`)
  console.log(`ok   ${what} = ${got}`)
}

const before = await node.getBalance(to)
const hash = await sendLocalCall(node, genesis, nativeTransfer(genesis.address, to, '4242'))
const tx = await node.waitForTransaction(hash, { interval: 300, timeout: 60000 })
check('recipient before', before, '0')
check('transaction kind', tx.kind, 'public')
check('hash of the decoded tx', tx.kind === 'public' ? transactionHash(tx.transaction) : '', hash)
check('recipient after', await node.getBalance(to), '4242')
const block = await node.getBlock(tx.block)
check('block lists the tx', block?.transactions?.map(transactionHash).includes(hash), true)
console.log('OK: S6 TS-built, TS-signed transfer landed on LEZ 0.3')
