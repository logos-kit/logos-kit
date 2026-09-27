#!/usr/bin/env node
// Install Logos Kit the way a user does, in a real Basecamp with an empty
// profile: Settings → Package Repositories → paste the catalog URL → Add →
// Applications → Logos Kit Wallet → Install… → Install → the wallet opens.
// Screenshots go to --shots. `e2e/catalog-install-gui.sh` launches Basecamp.
//
//   node tests/catalog-install-gui.mjs [--shots docs/reviews/s7/catalog]
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'

const FW =
  process.env.QT_MCP_FRAMEWORK ||
  path.join(os.homedir(), '.local/share/logos-tools/logos-qt-mcp/test-framework/framework.mjs')
const { Inspector, App } = await import(FW)

const CATALOG_URL =
  process.env.CATALOG_URL ||
  'https://raw.githubusercontent.com/logos-kit/logos-kit-modules/refs/heads/main/logos-repo.json'
const shotsArg = process.argv.indexOf('--shots')
const SHOTS = shotsArg > 0 ? process.argv[shotsArg + 1] : 'docs/reviews/s7/catalog'
fs.mkdirSync(SHOTS, { recursive: true })

const ins = new Inspector()
await ins.connect()
const app = new App(ins)
const say = (...a) => process.stdout.write(`${a.join(' ')}\n`)

async function evalOn(id, expression) {
  const r = await ins.send('evaluate', { objectId: id, expression })
  if (r.error) throw new Error(`evaluate(${expression}): ${r.error}`)
  return r.result
}
async function byName(objectName, timeout = 15000) {
  let id = null
  await app.waitFor(
    async () => {
      const r = await ins.send('findByProperty', { property: 'objectName', value: objectName })
      id = r.matches?.[0]?.id ?? null
      if (!id) throw new Error(`${objectName} not in the tree`)
    },
    { timeout, interval: 400, description: objectName },
  )
  return id
}
async function byType(typeName) {
  const r = await ins.send('findByType', { typeName })
  return r.matches ?? []
}
async function shot(name) {
  const r = await app.screenshot()
  if (r.image) fs.writeFileSync(path.join(SHOTS, `${name}.png`), Buffer.from(r.image, 'base64'))
  say('  shot', name)
}

// 1. Add the catalog.
say('1. Settings → Package Repositories → add', CATALOG_URL)
await app.click('Settings', { exact: true, type: 'SidebarCircleButton' })
await app.waitFor(() => app.expectTexts(['Package Repositories']), {
  timeout: 10000,
  interval: 400,
  description: 'Settings sections',
})
await app.click('Package Repositories', { exact: true })
const field = await byName('repositories.urlField')
await evalOn(field, `text = ${JSON.stringify(CATALOG_URL)}`)
await shot('01-add-repository')
await ins.send('callMethod', {
  objectId: await byName('repositories.addButton'),
  method: 'clicked',
})

let repo = null
await app.waitFor(
  async () => {
    const rows = JSON.parse(await evalOn(field, 'JSON.stringify(backend.repositories)'))
    repo = rows.find((r) => r.url === CATALOG_URL)
    if (!repo) throw new Error('catalog not in backend.repositories yet')
    if (repo.resolveError) throw new Error(`resolveError: ${repo.resolveError}`)
    if (!(repo.displayName || repo.name)) throw new Error('catalog not resolved yet')
  },
  { timeout: 60000, interval: 1000, description: 'the catalog to resolve' },
)
say('  resolved:', repo.displayName || repo.name)
await shot('02-repository-added')

// 2. Find the wallet in Applications and install it.
say('2. Applications → Logos Kit Wallet → Install…')
await app.click('Applications')
await app.waitFor(() => app.expectTexts(['Install and manage applications.']), {
  timeout: 10000,
  interval: 400,
  description: 'Applications view',
})
await evalOn(await byName('appManager.searchField'), 'text = "Logos Kit"')

// The visible grid tile for the wallet (hidden delegates for other sections
// share the type). A real click on an uninstalled app opens the install dialog.
let tile = null
await app.waitFor(
  async () => {
    for (const m of await byType('AppGridDelegate')) {
      const got = await ins.send('evaluate', {
        objectId: m.id,
        expression: 'visible && appData.name === "logos_kit_wallet_ui"',
      })
      if (got.result === true) {
        tile = m.id
        return
      }
    }
    throw new Error('no visible logos_kit_wallet_ui tile yet')
  },
  { timeout: 60000, interval: 1000, description: 'the wallet to appear in the catalog' },
)
await shot('03-catalog-lists-wallet')
await ins.send('click', { objectId: tile })

const primary = await byName('addApplicationDialog.primaryButton')
await app.waitFor(
  async () =>
    (await evalOn(primary, 'visible && enabled')) || Promise.reject(new Error('not ready')),
  {
    timeout: 30000,
    interval: 500,
    description: 'the Install button',
  },
)
say('  dialog button:', await evalOn(primary, 'text'))
await shot('04-install-dialog')
await ins.send('callMethod', { objectId: primary, method: 'clicked' })

// 3. Both packages land, then the wallet opens.
say('3. waiting for logos_kit_wallet_ui + logos_kit_wallet to install')
// The dialog's button turns into "Launch" once the UI and its core are on disk.
await app.waitFor(
  async () =>
    (await evalOn(primary, 'visible && enabled && text === "Launch"')) ||
    Promise.reject(new Error(`button says ${await evalOn(primary, 'text')}`)),
  { timeout: 600000, interval: 2000, description: 'the install to finish' },
)
await shot('05-installed')
await ins.send('click', { objectId: primary })
await app.waitFor(
  async () => {
    // In the tree is not enough: Basecamp shows a spinner until the view is
    // ready, so wait for the button and every ancestor to be visible.
    const r = await ins.send('findByProperty', { property: 'objectName', value: 'createWallet' })
    for (const m of r.matches ?? []) {
      const shown = await evalOn(
        m.id,
        '(function(o){ while (o) { if (o.visible === false) return false; o = o.parent } return true })(this)',
      )
      if (shown === true) return
    }
    throw new Error('wallet not on its welcome screen yet')
  },
  { timeout: 60000, interval: 1000, description: 'the wallet welcome screen' },
)
await new Promise((r) => setTimeout(r, 1500)) // let the first frame paint
await shot('06-wallet-opens')
say('CATALOG GUI INSTALL OK')
process.exit(0)
