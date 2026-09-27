import { defineConfig } from 'tsdown'

export default defineConfig({
  entry: ['src/index.ts'],
  format: ['esm'],
  platform: 'neutral',
  // The root ships into Qt's V4 engine (QML): lower syntax to ES2017.
  target: 'es2017',
  unbundle: true,
  dts: true,
  clean: true,
})
