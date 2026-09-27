import type { BaseLayoutProps } from 'fumadocs-ui/layouts/shared'
import { appName, gitConfig } from './shared'

export function baseOptions(): BaseLayoutProps {
  return {
    nav: {
      // JSX supported
      title: (
        <span className="inline-flex items-center gap-2 font-semibold">
          <img
            src="/logos-mark-white.svg"
            alt=""
            width={16}
            height={18}
            className="hidden dark:block"
          />
          <img src="/logos-mark-black.svg" alt="" width={16} height={18} className="dark:hidden" />
          {appName}
        </span>
      ),
    },
    githubUrl: `https://github.com/${gitConfig.user}/${gitConfig.repo}`,
  }
}
