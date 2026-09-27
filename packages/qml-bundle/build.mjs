// QML (Qt V4) build of the Logos Kit SDK, ported from the research pipeline
// (refs/connect-kits/_notes/artifacts/qml-transpile/pipe/build.mjs):
//   A  esbuild   entry → one ESM file (TS stripped, deps inlined)
//   B  babel     Qt V4 workarounds (`f.apply(t, typedArray)` passes undefined args)
//   C  esbuild   → IIFE with global `LogosKit`, target ES2016 (lowers async/await,
//                spread, classes' fields…); minified
//   D  prepend `.pragma library`, write sdk/qml/LogosKit/{logoskit.js,Tokens.js}
// Usage: node build.mjs [entry.ts out.js]   (the gate builds its suite this way)
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { transformAsync } from '@babel/core'
import * as esbuild from 'esbuild'

const here = path.dirname(fileURLToPath(import.meta.url))
const sdk = path.join(here, '../../sdk/qml/LogosKit')
const [
  entry = path.join(here, 'src/entry.ts'),
  out = path.join(sdk, 'logoskit.js'),
  globalName = 'LogosKit',
] = process.argv.slice(2)

// Libraries that probe for Node builtins get an empty module.
const nodeStubs = {
  name: 'node-stubs',
  setup(b) {
    b.onResolve({ filter: /^(crypto|buffer|node:crypto)$/ }, (a) => ({
      path: a.path,
      namespace: 'stub',
    }))
    b.onLoad({ filter: /.*/, namespace: 'stub' }, () => ({
      contents: 'module.exports = {}',
      loader: 'js',
    }))
  },
}

const a = await esbuild.build({
  entryPoints: [entry],
  bundle: true,
  format: 'esm',
  target: 'esnext',
  platform: 'neutral',
  mainFields: ['module', 'main'],
  write: false,
  logLevel: 'error',
  plugins: [nodeStubs],
})
let code = a.outputFiles[0].text
if (/\bBigInt\b|\b\d+n\b/.test(code.replace(/"(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'/g, ''))) {
  throw new Error('BigInt reached the QML bundle (Qt V4 has none)')
}

const b = await transformAsync(code, {
  filename: 'bundle.mjs',
  configFile: false,
  babelrc: false,
  sourceType: 'module',
  plugins: [path.join(here, 'babel-plugin-qml-v4.cjs')],
})
code = b.code

const c = await esbuild.build({
  stdin: { contents: code, resolveDir: here, sourcefile: 'bundle.B.mjs' },
  bundle: true,
  format: 'iife',
  globalName,
  target: 'es2016',
  minify: true,
  platform: 'neutral',
  write: false,
  logLevel: 'warning',
  plugins: [nodeStubs],
})
const final = `.pragma library\n${c.outputFiles[0].text}`
fs.mkdirSync(path.dirname(out), { recursive: true })
fs.writeFileSync(out, final)
// biome-ignore lint/suspicious/noConsole: build output
console.log(`built ${path.relative(process.cwd(), out)} ${final.length} bytes`)

if (out === path.join(sdk, 'logoskit.js')) {
  const { qmlTokensModule } = await import('@logos-kit/theme')
  fs.writeFileSync(path.join(sdk, 'Tokens.js'), qmlTokensModule())
}
