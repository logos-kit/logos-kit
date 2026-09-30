// Screens for the docs: read scripts/shots.config.mjs, and for each entry
// trim the capture's flat border, scale it (panels 960 px wide, windows
// 2000 px), encode WebP into public/shots/<name>.webp and record the size in
// lib/shots.json. Framing (radius, border, shadow, backdrop) is CSS in
// components/shot.tsx, so it follows the docs' light/dark theme.
//
//   pnpm shots            # all
//   pnpm shots wallet-*   # a glob over names
//
// Captures live in docs/reviews/**; re-shoot them with the harness or the
// e2e scripts, then run this again. Missing sources are reported, not fatal.
import fs from 'node:fs'
import path from 'node:path'
import sharp from 'sharp'
import { shots } from './shots.config.mjs'

const docs = path.resolve(import.meta.dirname, '..')
const root = path.resolve(docs, '../..')
const out = path.join(docs, 'public/shots')
const manifestPath = path.join(docs, 'lib/shots.json')
const WIDTH = { panel: 960, window: 2000 }

const filter = process.argv[2]
const match = (name) =>
  !filter ||
  new RegExp(`^${filter.replace(/[.+^${}()|[\]\\]/g, '\\$&').replace(/\*/g, '.*')}$`).test(name)

fs.mkdirSync(out, { recursive: true })
const manifest =
  filter && fs.existsSync(manifestPath) ? JSON.parse(fs.readFileSync(manifestPath, 'utf8')) : {}
let missing = 0
for (const [name, s] of Object.entries(shots)) {
  if (!match(name)) continue
  const src = path.join(root, s.src)
  if (!fs.existsSync(src)) {
    console.warn(`missing ${name}: ${s.src}`)
    missing++
    continue
  }
  const img = sharp(src).trim({ threshold: 2 })
  const { data, info } = await img
    .resize({ width: WIDTH[s.kind], withoutEnlargement: true })
    .webp({ quality: 90, effort: 6 })
    .toBuffer({ resolveWithObject: true })
  fs.writeFileSync(path.join(out, `${name}.webp`), data)
  manifest[name] = {
    kind: s.kind,
    light: Boolean(s.light),
    width: info.width,
    height: info.height,
    alt: s.alt,
    src: s.src,
  }
  console.log(`${name}: ${info.width}x${info.height} ${(data.length / 1024).toFixed(0)} KB`)
}
fs.writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`)
if (missing) console.warn(`${missing} source(s) missing`)
