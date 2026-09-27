#!/usr/bin/env node
// Integration flow (docs/dev/PLAN.md S7 QA step 6): the prize's core flow in a
// real Basecamp, through the shell's intents and sandbox.
//
//   probe dApp → lez.wallet.connect → shell chooser → ConnectSheet → approve
//              → lez.transaction.send → ApprovalSheet → approve → handle
//              → status (polled by the dApp through the core module) = included/success
//
// Needs: Basecamp (inspector build) running with logos_kit_wallet,
// logos_kit_wallet_ui and probe_dapp installed, and the standalone LEZ
// sequencer on :3040 (`just bc-flow` does all of it).
//
//   node tests/intent-flow.mjs [--shots docs/reviews/s7/basecamp]
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'

const FW =
  process.env.QT_MCP_FRAMEWORK ||
  path.join(os.homedir(), '.local/share/logos-tools/logos-qt-mcp/test-framework/framework.mjs')
const { Inspector } = await import(FW)

const shotsArg = process.argv.indexOf('--shots')
const SHOTS = shotsArg > 0 ? process.argv[shotsArg + 1] : 'docs/reviews/s7/basecamp'
fs.mkdirSync(SHOTS, { recursive: true })
const PW = 'correct horse 42'
const ins = new Inspector()
await ins.connect()

const say = (...a) => process.stdout.write(`${a.join(' ')}\n`)
const sleep = (ms) => new Promise((r) => setTimeout(r, ms))
async function send(cmd, params) {
  const r = await ins.send(cmd, params)
  if (r.error) throw new Error(`${cmd} ${JSON.stringify(params)}: ${r.error}`)
  return r
}
async function ids(name) {
  const r = await ins.send('findByProperty', { property: 'objectName', value: name })
  return (r.matches || []).map((m) => m.id)
}
async function visibleId(name) {
  for (const id of await ids(name)) {
    const v = await ins.send('evaluate', {
      objectId: id,
      expression:
        '(function(o){ while (o) { if (o.visible === false) return false; o = o.parent } return true })(this)',
    })
    if (v.result === true) return id
  }
  return null
}
async function waitFor(what, fn, timeout = 30000) {
  const end = Date.now() + timeout
  let last
  while (Date.now() < end) {
    try {
      const v = await fn()
      if (v) return v
    } catch (e) {
      last = e
    }
    await sleep(400)
  }
  throw new Error(`timed out: ${what}${last ? ` (${last.message})` : ''}`)
}
const waitVisible = (name, timeout) => waitFor(name, () => visibleId(name), timeout)
async function click(name, timeout) {
  const id = await waitVisible(name, timeout)
  // Buttons that arm after 500 ms, and busy ones, ignore early clicks.
  await waitFor(
    `${name} armed`,
    async () => {
      const r = await ins.send('evaluate', {
        objectId: id,
        expression: '(this.armed !== false) && this.enabled && !this.busy',
      })
      return r.result === true
    },
    20000,
  )
  await send('click', { objectId: id })
  await sleep(500)
}
async function type(name, text) {
  const id = await waitVisible(name)
  await send('setProperty', { objectId: id, property: 'text', value: text })
}
async function text(name) {
  const id = await visibleId(name)
  if (!id) return ''
  return (await ins.send('evaluate', { objectId: id, expression: 'this.text' })).result || ''
}
async function shot(label) {
  await sleep(700)
  const r = await ins.send('screenshot', {})
  if (r.image) fs.writeFileSync(path.join(SHOTS, `${label}.png`), Buffer.from(r.image, 'base64'))
  say('  shot', label)
}
async function openApp(title) {
  await send('findAndClick', { text: title })
  await sleep(1500)
}
async function step(name, fn) {
  process.stdout.write(`• ${name}\n`)
  try {
    await fn()
  } catch (e) {
    await shot(`fail-${name.replace(/\W+/g, '-')}`)
    throw e
  }
}

await step('wallet: first run on the local zone', async () => {
  await openApp('Logos Kit Wallet')
  const first = await waitFor(
    'wallet view',
    async () =>
      (await visibleId('createWallet')) ||
      (await visibleId('unlock')) ||
      (await visibleId('homeSend')),
  )
  const which = await ins.send('evaluate', { objectId: first, expression: 'this.objectName' })
  if (which.result === 'createWallet') {
    await send('findAndClick', { text: 'lez:local' })
    await sleep(1500)
    await shot('01-welcome')
    await click('createWallet')
    await type('password', PW)
    await type('password2', PW)
    await click('continueCreate')
    await click('revealPhrase', 60000)
    const ob = (await ids('onboarding'))[0]
    const words = (
      await ins.send('evaluate', { objectId: ob, expression: "this.words.join(' ')" })
    ).result.split(' ')
    await shot('02-phrase')
    await click('savedPhrase')
    for (const n of [3, 11, 19]) await type(`confirmWord${n}`, words[n - 1])
    await click('confirmPhrase')
    await click('readyFunds')
  } else if (which.result === 'unlock') {
    await type('unlockPassword', PW)
    await click('unlock')
  }
  await waitVisible('homeSend', 60000)
  // The faucet pays within a block or two on the local sequencer.
  await sleep(8000)
  await shot('03-wallet-home')
})

await step('dApp: connect through the shell', async () => {
  await openApp('Logos Kit Probe (dev only)')
  await click('probeConnect')
  // The shell asks which app should handle it (the wallet is the only provider).
  await waitFor(
    'wallet connect sheet',
    async () => {
      if (await visibleId('connectApprove')) return true
      for (const t of ['Logos Kit Wallet', 'logos_kit_wallet_ui'])
        await ins.send('findAndClick', { text: t })
      for (const t of ['Open', 'Continue', 'Use'])
        await ins.send('findAndClick', { text: t, exact: true })
      return false
    },
    30000,
  )
  await shot('10-connect-sheet')
  await type('connectPassword', PW)
  await click('connectApprove')
  await waitFor(
    'dApp connected',
    async () => /connected: 1 account/.test(await text('probeLog')),
    30000,
  )
  await shot('11-dapp-connected')
})

await step('dApp: send, approve in the wallet, follow the handle', async () => {
  await click('probeSend')
  await waitFor(
    'approval sheet',
    async () => {
      if (await visibleId('approve')) return true
      for (const t of ['Logos Kit Wallet', 'logos_kit_wallet_ui'])
        await ins.send('findAndClick', { text: t })
      return false
    },
    30000,
  )
  await shot('12-approval-sheet')
  await click('approve')
  await waitFor(
    'handle returned',
    async () => /approved, handle lk_/.test(await text('probeLog')),
    30000,
  )
  const status = await waitFor(
    'included',
    async () => {
      const t = await text('probeStatus')
      return /^included/.test(t) ? t : null
    },
    120000,
  )
  await shot('13-dapp-status')
  if (!/included \/ success/.test(status)) throw new Error(`unexpected status: ${status}`)
  say('  status:', status)
})

await step('dApp: reads through the core module', async () => {
  await click('probeBalance')
  await waitFor('balance read', async () => /^balance \d+/.test(await text('probeLog')), 20000)
  say('  ', await text('probeLog'))
})

say('\nOK: connect → send → approve → included/success, in Basecamp')
ins.disconnect()
process.exit(0)
