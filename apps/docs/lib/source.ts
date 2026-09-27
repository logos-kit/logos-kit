import { rehypeCodeDefaultOptions } from 'fumadocs-core/mdx-plugins'
import { llms, loader } from 'fumadocs-core/source'
import { lucideIconsPlugin } from 'fumadocs-core/source/lucide-icons'
import { metaSchema, pageSchema } from 'fumadocs-core/source/schema'
import { applyMdxPreset } from 'fumadocs-mdx/config'
import { defineDocs } from 'fumadocs-mdx/macro'
import { transformerTwoslash } from 'fumadocs-twoslash'
import {
  createFileSystemGeneratorCache,
  createGenerator,
  remarkAutoTypeTable,
} from 'fumadocs-typescript'
import { docsRoute } from './shared'

// Type tables for `<auto-type-table path=… name=… />`, read from the packages' sources.
const generator = createGenerator({
  cache: createFileSystemGeneratorCache('.next/fumadocs-typescript'),
})

const docs = defineDocs({
  dir: 'content/docs',
  docs: {
    schema: pageSchema,
    // Collection-level options replace the defaults, so start from the preset.
    mdxOptions: applyMdxPreset({
      remarkPlugins: [[remarkAutoTypeTable, { generator }]],
      rehypeCodeOptions: {
        ...rehypeCodeDefaultOptions,
        // `ts twoslash` blocks get type hovers from the real packages.
        transformers: [...(rehypeCodeDefaultOptions.transformers ?? []), transformerTwoslash()],
        // Shiki can't lazy-load languages inside Twoslash popups.
        langs: ['js', 'jsx', 'ts', 'tsx', 'json', 'bash', 'qml'],
      },
    }),
    postprocess: {
      includeProcessedMarkdown: true,
    },
  },
  meta: {
    schema: metaSchema,
  },
})

// See https://fumadocs.dev/docs/headless/source-api for more info
export const source = loader({
  baseUrl: docsRoute,
  source: docs.toFumadocsSource(),
  plugins: [lucideIconsPlugin()],
})

export const docsLlms = llms(source, {
  renderPage: async (page) => `# ${page.data.title} (${page.url})

${await page.data.getText('processed')}`,
})
