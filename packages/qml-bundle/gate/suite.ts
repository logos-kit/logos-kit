// QML engine gate: the same checks run in Node and in Qt 6.9.2 / 6.11.1
// (gate/run.sh diffs the logs). Everything a Basecamp app would reach.
import { parseJson } from '@logos-kit/client'
import {
  add,
  associatedTokenAccount,
  encodeMessage,
  encodeTransaction,
  formatUnits,
  fromHex,
  messageHash,
  parseUnits,
  readUle,
  sendTransactionParam,
  sha256,
  testimonialPost,
  toHex,
  transactionHash,
  u128le,
  utf8,
} from '@logos-kit/codec'
import { toQmlTokens, trayDark } from '@logos-kit/theme'
import programs from '../../../protocol/vectors/programs.json'
import publicTx from '../../../protocol/vectors/public_tx.json'
import { createLogosKit } from '../src/facade.ts'
import { installQmlHost } from '../src/qml-shims.js'

interface Host {
  log(s: string): void
  setTimeout(fn: () => void, ms: number): unknown
  clearTimeout(id: unknown): void
}

export async function run(host: Host): Promise<void> {
  installQmlHost(host)
  const log = (k: string, v: unknown) =>
    host.log(`${k} = ${typeof v === 'string' ? v : JSON.stringify(v)}`)

  // codec: hashing, the signed LEZ vector (bytes, hashes, RPC param)
  log('sha256("abc")', toHex(sha256(utf8('abc'))))
  log('sha256(1000 bytes)', toHex(sha256(new Uint8Array(1000).map((_, i) => i & 255))))
  const s = publicTx.signed[0] as (typeof publicTx.signed)[number]
  const f = s.fields
  const message = {
    program: f.programAccountId.base58,
    shardSelectors: f.shardSelectors.map((x) => ({
      account: x.accountId.base58,
      program: x.programAccountId.base58,
    })),
    nonces: f.nonces,
    instructionData: fromHex(f.instructionData),
    fee: {
      payer: f.fee.payer.base58,
      gasLimit: f.fee.gasLimit,
      tip: f.fee.tip,
      maxFee: f.fee.maxFee,
    },
  }
  log('message borsh matches LEZ', toHex(encodeMessage(message)) === s.borsh)
  log('message hash matches LEZ', toHex(messageHash(message)) === s.hash)
  const tx = {
    message,
    witnesses: [{ signature: fromHex(s.signature), publicKey: fromHex(s.publicKey) }],
  }
  log('tx bytes match LEZ', toHex(encodeTransaction(tx)) === s.transaction.borsh)
  log('tx hash matches LEZ', transactionHash(tx) === s.rpc.txHash)
  log('RPC param matches LEZ', sendTransactionParam(tx) === s.rpc.sendTransactionParam)
  const ata = programs.associatedTokenAccount
  log(
    'token account address matches LEZ',
    associatedTokenAccount(ata.owner, ata.definition) === ata.ata,
  )
  const t = programs.testimonial[0] as (typeof programs.testimonial)[number]
  const post = testimonialPost({
    program: t.program,
    author: t.author,
    text: t.text,
    username: t.username ?? undefined,
    submission: t.submission,
    page: t.page,
    timestampMs: t.timestampMs,
  })
  log('testimonial data matches Rust', toHex(post.data) === t.data)
  log(
    'testimonial accounts',
    post.accounts.map((a) => a.account).join(',') === [t.author, t.stats, t.record].join(','),
  )

  // u128 without BigInt, lossless JSON, theme
  const max = '340282366920938463463374607431768211455'
  log('u128 max round trip', readUle(u128le(max)) === max)
  log('add', add('18446744073709551615', '1'))
  log('units', `${formatUnits('1500000', 6)} ${parseUnits('0.000005', 6)}`)
  // LGO: lepta on the wire, 9 decimals on screen; past 2^53 without a Number.
  log(
    'lgo',
    `${formatUnits('1', 9)} ${formatUnits('18446744073709551615', 9)} ${parseUnits('2.5', 9)}`,
  )
  log('lossless JSON', (parseJson(`{"balance":${max}}`) as { balance: string }).balance === max)
  log('tokens', toQmlTokens(trayDark).privateSoft)

  // shims, exercised inside the engine (Qt locks builtins; these are added)
  const shimmed = Object as unknown as {
    hasOwn(o: object, k: string): boolean
    fromEntries(it: unknown[]): object
  }
  log('Object.hasOwn', shimmed.hasOwn({ a: 1 }, 'a') && !shimmed.hasOwn({}, 'toString'))
  log(
    'Array.flat',
    JSON.stringify(([[1, [2]], 3] as unknown as { flat(d: number): unknown }).flat(2)),
  )
  const fe = shimmed.fromEntries([['__proto__', 1]]) as Record<string, unknown>
  log(
    'fromEntries keeps __proto__ a key',
    Object.getPrototypeOf(fe) === Object.prototype &&
      Object.getOwnPropertyDescriptor(fe, '__proto__')?.value === 1,
  )

  // facade against a mock wallet: intents, busy guard, timeout + late answer,
  // watch, testimonial (page read through lez_readAccount)
  const statuses = ['awaiting_approval', 'signing', 'submitted', 'included']
  let polls = 0
  const pending: Array<() => void> = []
  let lateSign: ((res: { ok: boolean; data?: unknown }) => void) | undefined
  const late: string[] = []
  const methods: string[] = []
  const kit = createLogosKit({
    chain: 'lez:testnet',
    intentTimeoutMs: 200,
    onLateResult: (intent, ok, data) => late.push(`${intent} ${ok} ${JSON.stringify(data)}`),
    callModuleAsync: (_m, method, _args, cb) => {
      methods.push(method)
      if (method === 'lez_getTransactionStatus') {
        const lifecycle = statuses[Math.min(polls++, statuses.length - 1)]
        host.setTimeout(
          () =>
            cb(
              JSON.stringify({
                value: {
                  handle: 'h1',
                  lifecycle,
                  outcome: lifecycle === 'included' ? 'success' : 'unknown',
                },
              }),
            ),
          1,
        )
      } else if (method === 'lez_getAccounts') cb('{"value":[{"address":"A","kind":"public"}]}')
      else if (method === 'lez_readAccount') cb('{"value":{"nonce":"0","data":""}}')
      else cb('{"error":{"code":-32601,"message":"no such method"}}')
    },
    openIntent: (intent, params, cb) => {
      const p = params as { id?: string; instructions?: { data: string }[] }
      if (intent === 'lez.wallet.connect')
        pending.push(() => cb({ ok: true, data: { sessionId: 's1' } }))
      else if (intent === 'lez.transaction.send')
        cb({
          ok: true,
          data: { handle: 'h1', hasId: !!p.id, data: p.instructions?.[0]?.data.length ?? 0 },
        })
      else if (intent === 'lez.message.sign') lateSign = cb
      else cb({ ok: false, error: 'cancelled' })
    },
  })
  const connecting = kit.connect()
  log('busy during connect', kit.isBusy())
  const second = await kit.requestFunds('A').catch((e: { code: number }) => e.code)
  log('second request while busy', second)
  const release = pending.shift()
  if (release) release()
  log('connect', await connecting)
  log('busy after', kit.isBusy())
  log('accounts', await kit.getAccounts())
  log('timeout', await kit.signMessage('A', 'hi').catch((e: { code: number }) => e.code))
  log('still busy after a timeout', kit.isBusy())
  log(
    'refused while the sheet may be open',
    await kit.requestFunds('A').catch((e: { code: number }) => e.code),
  )
  if (lateSign) lateSign({ ok: true, data: { signature: 'sig' } })
  log('late answer delivered', late)
  log('free after the late answer', !kit.isBusy())
  log('user rejection', await kit.requestFunds('A').catch((e: { code: number }) => e.code))
  const sent = await kit.postTestimonial({
    program: t.program,
    author: t.author,
    text: 'hi',
    timestampMs: 1,
  })
  log('testimonial sent', sent)
  log('module calls', methods.join(','))
  const seen: string[] = []
  const final = await new Promise<string>((resolve, reject) => {
    kit.watchTransaction(
      'h1',
      (st) => {
        seen.push(st.lifecycle)
        if (st.lifecycle === 'included') resolve(st.outcome)
      },
      reject,
      { interval: 5 },
    )
  })
  log('watched lifecycles', seen.join(' > '))
  log('final outcome', final)
}
