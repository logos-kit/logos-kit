'use client'

// Adapted from Magic UI's "Script Copy Button" (dillionverma, MIT) via 21st.dev:
// same tabs + shiki + copy behaviour, without the shadcn Button dependency.
import { Check, Copy } from 'lucide-react'
import { motion } from 'motion/react'
import { useTheme } from 'next-themes'
import { useEffect, useState } from 'react'
import { codeToHtml } from 'shiki'
import { cn } from '@/lib/cn'

export function ScriptCopy({
  commands,
  icons,
  className,
}: {
  commands: Record<string, string>
  /** Optional logo per tab (e.g. npm), shown before its name. */
  icons?: Record<string, string>
  className?: string
}) {
  const names = Object.keys(commands)
  const [active, setActive] = useState(names[0]!)
  const [copied, setCopied] = useState(false)
  const [html, setHtml] = useState('')
  const { resolvedTheme } = useTheme()
  const command = commands[active]!

  useEffect(() => {
    let live = true
    codeToHtml(command, {
      lang: 'shell',
      themes: { light: 'github-light', dark: 'github-dark' },
      defaultColor: resolvedTheme === 'light' ? 'light' : 'dark',
    })
      .then((h) => live && setHtml(h))
      .catch(() => live && setHtml(''))
    return () => {
      live = false
    }
  }, [command, resolvedTheme])

  return (
    <div className={cn('w-full max-w-xl', className)}>
      <div className="mb-2 inline-flex overflow-hidden rounded-full border border-fd-border p-0.5 text-xs">
        {names.map((n) => (
          <button
            key={n}
            type="button"
            onClick={() => setActive(n)}
            className={cn(
              'relative rounded-full px-3 py-1 transition-colors',
              active === n
                ? 'text-fd-foreground'
                : 'text-fd-muted-foreground hover:text-fd-foreground',
            )}
          >
            {active === n && (
              <motion.span
                layoutId="script-copy-tab"
                className="absolute inset-0 rounded-full bg-fd-secondary"
                transition={{ type: 'spring', stiffness: 500, damping: 34 }}
              />
            )}
            <span className="relative inline-flex items-center gap-1.5">
              {icons?.[n] && (
                // biome-ignore lint/performance/noImgElement: a 12 px local logo
                <img
                  src={icons[n]}
                  alt=""
                  width={12}
                  height={12}
                  className="h-3 w-3 rounded-[2px]"
                />
              )}
              {n}
            </span>
          </button>
        ))}
      </div>
      <div className="flex items-center gap-2 rounded-2xl border border-fd-border bg-fd-card py-1 pr-1 pl-4">
        <span className="select-none font-mono text-fd-muted-foreground text-sm">$</span>
        <div className="min-w-0 grow overflow-x-auto font-mono text-sm [&_pre]:!bg-transparent [&_pre]:py-2.5">
          {html ? (
            // biome-ignore lint/security/noDangerouslySetInnerHtml: shiki's HTML for our own constant commands
            <div dangerouslySetInnerHTML={{ __html: html }} />
          ) : (
            <pre className="py-2.5">{command}</pre>
          )}
        </div>
        <button
          type="button"
          aria-label={copied ? 'Copied' : 'Copy command'}
          onClick={() => {
            navigator.clipboard.writeText(command)
            setCopied(true)
            setTimeout(() => setCopied(false), 1800)
          }}
          className="grid size-9 shrink-0 place-items-center rounded-xl text-fd-muted-foreground transition hover:bg-fd-secondary hover:text-fd-foreground active:scale-95"
        >
          <motion.span
            key={copied ? 'y' : 'n'}
            initial={{ scale: 0.6, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
          >
            {copied ? (
              <Check className="size-4 text-[var(--lk-ok)]" />
            ) : (
              <Copy className="size-4" />
            )}
          </motion.span>
        </button>
      </div>
    </div>
  )
}
