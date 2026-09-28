import { createMDX } from 'fumadocs-mdx/next'

const withMDX = createMDX()

/** @type {import('next').NextConfig} */
const config = {
  reactStrictMode: true,
  // Twoslash and the type tables run the TypeScript compiler at build time.
  serverExternalPackages: ['typescript', 'twoslash'],
}

export default withMDX(config)
