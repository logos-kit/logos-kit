// Integration-confidence: lossless JSON and decoding on responses recorded
// from a LEZ 0.3 sequencer (test/fixtures; `*.synthetic.json` are the same
// shapes with u128::MAX, which a fresh chain never produces).
import { readdirSync, readFileSync } from 'node:fs'
import {
  fromHex,
  messageHash,
  nativeTransfer,
  testimonialPost,
  toBase64,
  transactionHash,
} from '@logos-kit/codec'
import { verifyHash } from '@logos-kit/codec/sign'
import { LezError } from '@logos-kit/protocol'
import { describe, expect, it } from 'vitest'
import {
  basecampModule,
  createClient,
  custom,
  decodeAccount,
  decodeBlock,
  decodeTransactionResult,
  nativeBalance,
  nodeActions,
  parseJson,
  poll,
  RpcError,
  TimeoutError,
  walletActions,
} from '../src/index.ts'
import { localAccount, sendCall } from '../src/local.ts'

const dir = new URL('./fixtures/', import.meta.url)
const raw = (f: string) => readFileSync(new URL(f, dir), 'utf8')
// biome-ignore lint/suspicious/noExplicitAny: fixture JSON
const result = (f: string): any => (parseJson(raw(f)) as { result: unknown }).result
const U128_MAX = '340282366920938463463374607431768211455'
const TX = '2b55e958da92b01ada39fd85a8b8b248e9adc8b2e262a6c959f26eac4eb0f0b9'

describe('lossless JSON', () => {
  it('agrees with JSON.parse on every recorded fixture', () => {
    for (const f of readdirSync(dir).filter(
      (f) => f.endsWith('.json') && !f.includes('synthetic'),
    )) {
      expect(parseJson(raw(f)), f).toEqual(JSON.parse(raw(f)))
    }
  })
  it('keeps u128 values that JSON.parse would round', () => {
    expect(result('getAccountBalance.u128max.synthetic.json')).toBe(U128_MAX)
    expect(JSON.parse(raw('getAccountBalance.u128max.synthetic.json')).result).not.toBe(U128_MAX)
    const acct = decodeAccount(result('getAccount.u128max.synthetic.json'))
    expect(acct.nonce).toBe(U128_MAX)
    expect(nativeBalance(acct)).toBe(U128_MAX)
  })
  it('handles escapes, nesting, and refuses junk', () => {
    expect(parseJson('{"a":"x\\n\\u00e9","b":[1,-2.5e3,{"c":null}],"__proto__":1}')).toEqual(
      JSON.parse('{"a":"x\\n\\u00e9","b":[1,-2.5e3,{"c":null}],"__proto__":1}'),
    )
    expect(({} as { polluted?: number }).polluted).toBeUndefined()
    expect(() => parseJson('{"a":1} x')).toThrow()
    expect(() => parseJson('[1,]')).toThrow()
  })
})

describe('recorded responses decode', () => {
  it('accounts and balances', () => {
    expect(nativeBalance(decodeAccount(result('getAccount.json')))).toBe('1234567')
    expect(nativeBalance(decodeAccount(result('getAccountView.json')))).toBe(
      String(result('getAccountBalance.json')),
    )
    expect(decodeAccount(result('getAccount.genesis.json')).nonce).toBe('1')
  })
  it('the transaction hashes back to the hash the wallet got', () => {
    const t = decodeTransactionResult(result('getTransaction.json'))
    expect(t?.kind).toBe('public')
    if (t?.kind !== 'public') return
    expect(transactionHash(t.transaction)).toBe(TX)
    const w = t.transaction.witnesses[0]
    expect(w && verifyHash(w.signature, messageHash(t.transaction.message), w.publicKey)).toBe(true)
    expect(decodeTransactionResult(result('getTransaction.missing.json'))).toBeNull()
  })
  it('blocks: header and public transactions', () => {
    const b = decodeBlock(result('getBlock.json'))
    const t = decodeTransactionResult(result('getTransaction.json'))
    expect(b.header.id).toBe(String(result('getTransaction.json')[1]))
    expect(b.header.timestamp).toBeGreaterThan(1.7e12)
    expect(b.transactions?.map(transactionHash)).toContain(TX)
    expect(t?.kind === 'public' && b.transactions?.length).toBe(b.transactionCount)
  })
})

function replay() {
  const map: Record<string, string> = {
    getLastBlockId: 'getLastBlockId.json',
    getAccountBalance: 'getAccountBalance.json',
    getFeeState: 'getFeeState.json',
    getTransaction: 'getTransaction.json',
    getAccountsNonces: 'getAccountsNonces.json',
  }
  const seen: { method: string; params: unknown }[] = []
  const transport = custom({
    async request({ method, params }) {
      seen.push({ method, params })
      if (method === 'sendTransaction') return TX
      const f = map[method]
      if (!f) throw new RpcError(-32601, 'Method not found')
      return (parseJson(raw(f)) as { result: unknown }).result
    },
  })
  return { client: createClient({ transport, chain: 'lez:local' }).extend(nodeActions), seen }
}

describe('node actions over a transport', () => {
  it('reads and waits', async () => {
    const { client } = replay()
    expect(await client.getBlockNumber()).toBe('3')
    expect(await client.getBalance('J2ZpoZWRdsnxfw6UQApFbRE87gifM4S9EBvyXaSUZsiJ')).toBe('1234567')
    expect((await client.getFeeState()).maxGasExec).toBe('10000000')
    expect((await client.waitForTransaction(TX, { interval: 1 })).kind).toBe('public')
    await expect(client.getBalance('not-an-account')).rejects.toThrow()
  })
  it('a local account signs exactly what it sends', async () => {
    const { client, seen } = replay()
    const key = fromHex('7f273098f25b71e6c005a9519f2678da8d1c7f01f6a27778e2d9948abdf901fb')
    const acct = localAccount(key)
    const hash = await sendCall(client, acct, nativeTransfer(acct.address, acct.address, '5'))
    expect(hash).toBe(TX)
    const param = seen.find((s) => s.method === 'sendTransaction')?.params as string[]
    const tx = decodeTransactionResult([param[0], 0])
    expect(tx?.kind).toBe('public')
    if (tx?.kind !== 'public') return
    expect(tx.transaction.message.nonces).toEqual(['1'])
    expect(tx.transaction.message.fee?.maxFee).toBe('134400000')
  })
})

describe('Basecamp module transport + wallet actions', () => {
  it('unwraps values and maps errors to LezError', async () => {
    const calls: unknown[][] = []
    const callModuleAsync = (
      m: string,
      method: string,
      args: unknown[],
      cb: (p: string) => void,
    ) => {
      calls.push([m, method, args])
      if (method === 'lez_getTransactionStatus')
        cb('{"value":{"handle":"h","lifecycle":"included","outcome":"success"}}')
      else if (method === 'lez_signAndSendTransaction') cb('{"value":"{\\"handle\\":\\"h\\"}"}')
      else cb('{"error":{"code":4001,"message":"Request declined"}}')
    }
    const w = createClient({
      transport: basecampModule({ callModuleAsync }),
      chain: 'lez:testnet',
    }).extend(walletActions)
    const author = 'J2ZpoZWRdsnxfw6UQApFbRE87gifM4S9EBvyXaSUZsiJ'
    const program = 'cGfHiC6Kgg3FpFZvgwGcswsCRtp4aBP2fzuXRQPizuN'
    expect(
      await w.postTestimonial({ program, author, text: 'I use Logos Kit', timestampMs: 1 }),
    ).toEqual({ handle: 'h' })
    const first = calls[0] as unknown[]
    const sent = JSON.parse((first[2] as string[])[0] as string)
    expect(first[0]).toBe('logos_kit_wallet')
    expect(sent.account).toBe(author)
    expect(sent.instructions[0].data).toBe(
      toBase64(testimonialPost({ program, author, text: 'I use Logos Kit', timestampMs: 1 }).data),
    )
    expect((await w.waitForTransactionStatus('h', { interval: 1 })).outcome).toBe('success')
    const err = await w.connect({ chains: ['lez:testnet'] }).catch((e) => e)
    expect(err).toBeInstanceOf(LezError)
    expect(err.code).toBe(4001)
  })
  it('poll pauses while hidden and times out', async () => {
    let calls = 0
    await expect(
      poll(
        async () => {
          calls++
          return undefined
        },
        'never',
        { timeout: 30, interval: 5, isVisible: () => false },
      ),
    ).rejects.toBeInstanceOf(TimeoutError)
    expect(calls).toBe(0)
  })
})
