// QML gate for a package's built output: every .js file under <dist> must
// parse as ES2017 (Qt's V4 engine). Usage: node scripts/check-es2017.ts <dist> [skip...]
import { readdirSync, readFileSync } from 'node:fs'
import { join } from 'node:path'
import { parse } from 'acorn'

const [dist, ...skip] = process.argv.slice(2)
if (!dist) throw new Error('usage: check-es2017.ts <dist> [skip...]')
const files = readdirSync(dist).filter((f) => f.endsWith('.js') && !skip.includes(f))
let failed = false
for (const f of files) {
  try {
    parse(readFileSync(join(dist, f), 'utf8'), { ecmaVersion: 2017, sourceType: 'module' })
  } catch (err) {
    failed = true
    console.error(`${f}: not ES2017 (${(err as Error).message})`)
  }
}
if (failed) process.exit(1)
console.log(`QML gate: ${files.length} files in ${dist} parse as ES2017`)
