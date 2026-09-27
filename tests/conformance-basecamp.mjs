#!/usr/bin/env node
// e2e/conformance-basecamp.sh: open the dApp in a real Basecamp next to the
// fake wallet, press its connect button, let the shell route the intent to
// the fake's provider, then check the fake's call log.
import fs from 'node:fs'
import path from 'node:path'
import { click, openApp, say, send, shot, sleep, visibleId, waitFor } from './bc-lib.mjs'

const { TITLE, APP, CONNECT, DIR } = process.env
const logFile = () => {
  const base = path.join(DIR, 'module_data/logos_kit_wallet')
  for (const inst of fs.existsSync(base) ? fs.readdirSync(base) : []) {
    const f = path.join(base, inst, 'fake-calls.jsonl')
    if (fs.existsSync(f)) return f
  }
  return null
}
const entries = () => {
  const f = logFile()
  return f
    ? fs
        .readFileSync(f, 'utf8')
        .split('\n')
        .filter(Boolean)
        .map((l) => JSON.parse(l))
    : []
}

const results = []
const check = (id, ok, detail) => {
  results.push({ id, ok, detail })
  say(`  ${ok ? 'PASS' : 'FAIL'}  ${id}: ${detail}`)
}

await openApp(TITLE)
await sleep(8000)
await shot('01-loaded')
const early = entries()
const mine = early.filter((e) => e.kind === 'call' && e.app === APP)
check(
  'loads-and-reaches-wallet',
  mine.length > 0,
  mine.length
    ? `${mine.length} calls attested as ${APP}`
    : 'no call from the dApp reached the wallet (sandbox, dependency or bridge)',
)
const others = early.filter(
  (e) => e.kind === 'call' && e.app !== APP && e.app !== 'logos_kit_wallet_fake',
)
check(
  'identity-attested',
  others.length === 0,
  others.length
    ? `calls arrived as ${[...new Set(others.map((e) => e.app))].join(', ')}`
    : 'every dApp call carries its module name',
)

if (CONNECT && (await visibleId(CONNECT))) {
  await click(CONNECT)
  // The shell asks which provider handles the intent: pick the fake.
  await waitFor(
    'connect answered',
    async () => {
      const row = await visibleId('intentProvider_logos_kit_wallet_fake')
      if (row) await send('click', { objectId: row })
      return entries().some(
        (e) => e.kind === 'intent' && e.name === 'lez.wallet.connect' && e.app === APP,
      )
    },
    60000,
  )
  await sleep(5000)
  await shot('02-after-connect')
  const all = entries()
  const intent = all.find((e) => e.kind === 'intent' && e.name === 'lez.wallet.connect')
  check(
    'connect-through-shell',
    !!intent && intent.app === APP,
    intent
      ? `lez.wallet.connect from ${intent.app} reached the provider, answer ok=${intent.answer.ok}`
      : 'no connect intent',
  )
  const after = all.filter(
    (e) => intent && e.seq > intent.seq && e.kind === 'call' && e.app === APP,
  )
  check(
    'uses-the-session',
    !intent?.answer.ok || after.length > 0,
    after.length
      ? `then ${[...new Set(after.map((e) => e.method))].join(', ')}`
      : 'nothing after connect',
  )
} else {
  check('connect-through-shell', false, `no visible "${CONNECT}" button to start a connect`)
}
fs.writeFileSync(
  path.join(path.dirname(`${process.argv[process.argv.indexOf('--shots') + 1]}/x`), 'report.json'),
  JSON.stringify({ app: APP, results, log: entries() }, null, 2),
)
const failed = results.filter((r) => !r.ok).length
say(`${results.length - failed}/${results.length} Basecamp checks passed`)
process.exit(failed ? 1 : 0)
