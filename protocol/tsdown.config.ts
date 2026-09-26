import { defineConfig } from 'tsdown'

export default defineConfig({
  entry: ['src/exports/index.ts', 'src/exports/schema.ts'],
  format: ['esm'],
  platform: 'neutral',
  unbundle: true,
  dts: true,
  clean: true,
})
