import { createMDX } from 'fumadocs-mdx/next'

const withMDX = createMDX()

/** @type {import('next').NextConfig} */
const config = {
  reactStrictMode: true,
  // Twoslash and the type tables run the TypeScript compiler at build time.
  serverExternalPackages: ['typescript', 'twoslash'],
  // Pages that moved when the docs were reorganised (2026-09-29).
  async redirects() {
    return [
      ['/docs/quickstart', '/docs/getting-started/quickstart'],
      ['/docs/networks', '/docs/concepts/networks'],
      ['/docs/security', '/docs/wallet/security'],
      ['/docs/sdk/errors', '/docs/reference/errors'],
    ].map(([source, destination]) => ({ source, destination, permanent: true }))
  },
}

export default withMDX(config)
