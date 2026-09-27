// Shared helpers for driving a real Basecamp (inspector build) over logos-qt-mcp.
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'

const FW =
  process.env.QT_MCP_FRAMEWORK ||
  path.join(os.homedir(), '.local/share/logos-tools/logos-qt-mcp/test-framework/framework.mjs')
const { Inspector } = await import(FW)

const shotsArg = process.argv.indexOf('--shots')
export const SHOTS = shotsArg > 0 ? process.argv[shotsArg + 1] : 'docs/reviews/basecamp'
fs.mkdirSync(SHOTS, { recursive: true })
export const PW = 'correct horse 42'
export const ins = new Inspector()
await ins.connect()

export const say = (...a) => process.stdout.write(`${a.join(' ')}\n`)
export const sleep = (ms) => new Promise((r) => setTimeout(r, ms))
export async function send(cmd, params) {
  const r = await ins.send(cmd, params)
  if (r.error) throw new Error(`${cmd} ${JSON.stringify(params)}: ${r.error}`)
  return r
}
export async function ids(name) {
  const r = await ins.send('findByProperty', { property: 'objectName', value: name })
  return (r.matches || []).map((m) => m.id)
}
export async function visibleId(name) {
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
export async function waitFor(what, fn, timeout = 30000) {
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
export const waitVisible = (name, timeout) => waitFor(name, () => visibleId(name), timeout)
export async function click(name, timeout) {
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
export async function type(name, text) {
  const id = await waitVisible(name)
  await send('setProperty', { objectId: id, property: 'text', value: text })
}
export async function text(name) {
  const id = await visibleId(name)
  if (!id) return ''
  return (await ins.send('evaluate', { objectId: id, expression: 'this.text' })).result || ''
}
export async function shot(label) {
  await sleep(700)
  const r = await ins.send('screenshot', {})
  if (r.image) fs.writeFileSync(path.join(SHOTS, `${label}.png`), Buffer.from(r.image, 'base64'))
  say('  shot', label)
}
// The shell asks which app should handle an intent: pick the wallet by the
// chooser's own objectName (a text click could hit the wallet's tab instead).
export async function chooseWallet() {
  const row = await visibleId('intentProvider_logos_kit_wallet_ui')
  if (row) await send('click', { objectId: row })
}
export async function openApp(title) {
  await send('findAndClick', { text: title })
  await sleep(1500)
}
export async function step(name, fn) {
  process.stdout.write(`• ${name}\n`)
  try {
    await fn()
  } catch (e) {
    await shot(`fail-${name.replace(/\W+/g, '-')}`)
    throw e
  }
}
