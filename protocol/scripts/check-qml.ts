// QML gate for the built runtime entry. Qt's V4 engine is ES2017-level, so
// anything newer (class fields, optional chaining, `??`, named regex groups,
// BigInt literals) must never reach the QML bundle. Biome and tsconfig.qml.json
// check the sources; this parses what tsdown actually emitted.
import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { parse } from 'acorn'

const dist = join(dirname(fileURLToPath(import.meta.url)), '..', 'dist')
const files = ['index.js', 'caip.js', 'constants.js', 'errors.js']

let failed = false
for (const file of files) {
  const code = readFileSync(join(dist, file), 'utf8')
  try {
    parse(code, { ecmaVersion: 2017, sourceType: 'module' })
  } catch (err) {
    failed = true
    console.error(`${file}: not ES2017 (${(err as Error).message})`)
  }
}
if (failed) process.exit(1)
console.log(`QML gate: ${files.length} runtime files parse as ES2017`)
