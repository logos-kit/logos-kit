import * as Twoslash from 'fumadocs-twoslash/ui'
import { Step, Steps } from 'fumadocs-ui/components/steps'
import { TypeTable } from 'fumadocs-ui/components/type-table'
import defaultMdxComponents from 'fumadocs-ui/mdx'
import type { MDXComponents } from 'mdx/types'

export function getMDXComponents(components?: MDXComponents) {
  return {
    ...defaultMdxComponents,
    ...Twoslash,
    TypeTable,
    Step,
    Steps,
    ...components,
  } satisfies MDXComponents
}

export const useMDXComponents = getMDXComponents

declare global {
  type MDXProvidedComponents = ReturnType<typeof getMDXComponents>
}
