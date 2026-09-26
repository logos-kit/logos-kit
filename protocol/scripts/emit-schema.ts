// Emit the canonical, committed JSON artifacts from the TypeBox sources:
//   schema/lws0.schema.json  every named schema under $defs (JSON Schema 2020-12)
//   schema/methods.json      method table: name → params/result schema, userFacing
//   schema/intents.json      Basecamp `provides` entries (also written into
//                            modules/logos_kit_wallet_ui/metadata.json)
// Rust (typify) and docs consume these; CI fails if they drift from the sources.
import { readFileSync, writeFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { LWS_VERSION } from '../src/constants.ts'
import { Intents } from '../src/schema/intents.ts'
import * as Msg from '../src/schema/messaging.ts'
import { Methods, Notifications } from '../src/schema/methods.ts'
import * as Prim from '../src/schema/primitives.ts'
import * as Sess from '../src/schema/session.ts'
import * as Tx from '../src/schema/transaction.ts'

const root = join(dirname(fileURLToPath(import.meta.url)), '..')
const plain = (v: unknown) => JSON.parse(JSON.stringify(v))
const write = (file: string, data: unknown) =>
  writeFileSync(join(root, 'schema', file), `${JSON.stringify(plain(data), null, 2)}\n`)

const defs: Record<string, unknown> = {}
for (const mod of [Prim, Sess, Tx, Msg]) {
  for (const [name, schema] of Object.entries(mod)) {
    // Modules also export plain constants (e.g. INTENT_MAX_STRING); only schemas go in $defs.
    if (typeof schema === 'object' && schema !== null) defs[name] = schema
  }
}

write('lws0.schema.json', {
  $schema: 'https://json-schema.org/draft/2020-12/schema',
  $id: 'https://logos-kit.dev/schema/lws0.schema.json',
  title: 'LWS-0: Logos Kit wallet protocol',
  version: LWS_VERSION,
  $defs: defs,
})

write('methods.json', {
  version: LWS_VERSION,
  methods: Object.fromEntries(
    Object.entries(Methods).map(([name, m]) => [
      name,
      { userFacing: m.userFacing, params: m.params, result: m.result },
    ]),
  ),
  notifications: Notifications,
})

write('intents.json', { version: LWS_VERSION, intents: Intents })

// The wallet UI's Basecamp `provides` is generated from the same source, so the
// shell enforces exactly the params the protocol declares. Other keys are kept.
const uiMeta = join(root, '..', 'modules', 'logos_kit_wallet_ui', 'metadata.json')
const meta = JSON.parse(readFileSync(uiMeta, 'utf8'))
meta.provides = Intents.map((i) => ({
  intent: i.intent,
  params: i.params,
  ...(i.handoff ? { handoff: true } : {}),
  ...(i.web ? { web: true } : {}),
}))
writeFileSync(uiMeta, `${JSON.stringify(meta, null, 2)}\n`)

console.log(
  `emitted LWS-0 ${LWS_VERSION}: ${Object.keys(defs).length} schemas, ${Object.keys(Methods).length} methods, ${Intents.length} intents`,
)
