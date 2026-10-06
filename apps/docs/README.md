# Logos Kit docs

The source of [logos-kit-docs.vercel.app](https://logos-kit-docs.vercel.app):
guides, concepts and the reference for the Logos Kit wallet and SDK. Built with
[Next.js](https://nextjs.org) and [Fumadocs](https://fumadocs.dev).

```sh
pnpm install                 # at the repository root
cd apps/docs && pnpm dev     # http://localhost:3000
pnpm build                   # builds the workspace packages, regenerates the reference, then next build
```

The site imports `@logos-kit/client`, `@logos-kit/codec` and
`@logos-kit/protocol` from the workspace, so `pnpm build` first builds them
(`prebuild`).

## Layout

| Path | What |
|---|---|
| `content/docs/**/*.mdx` | The pages. `content/docs/meta.json` sets the sidebar order |
| `content/docs/reference/methods.mdx` | Generated: run `pnpm gen` (also part of `pnpm build`). It is built from the protocol's schema and the wallet module's contract (`.lidl`); hand-written notes live in `scripts/method-notes.mjs` |
| `app/(home)` | The landing page, including the live testnet block height |
| `app/docs` | The docs layout and pages |
| `app/llms.txt`, `app/llms-full.txt`, `app/llms.mdx` | Plain-text and Markdown versions of the docs |
| `components/` | MDX components: `Shot` (screenshots), npm badges, landing sections |
| `public/shots/` | Screenshots, made by `pnpm shots` from captures in `docs/reviews/**` (sizes in `lib/shots.json`) |

## Screenshots

`pnpm shots` reads `scripts/shots.config.mjs`, trims and scales each capture,
writes WebP files to `public/shots/` and records their sizes. `pnpm shots
'wallet-*'` limits it to matching names. Re-shoot captures with the wallet
harness or the e2e scripts first; missing sources are reported, not fatal.

## Deploy

The site deploys to the Vercel project `logos-kit-docs`. Nothing is deployed
without the maintainer's go-ahead ([`AGENTS.md`](../../AGENTS.md)).
