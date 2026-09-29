'use client'

// QML and TypeScript side by side: tabs, shiki highlighting and copy, from
// the same 21st.dev Script Copy pattern as the install box (dillionverma).
import { Check, Copy } from 'lucide-react'
import { motion } from 'motion/react'
import { useEffect, useState } from 'react'
import { codeToHtml } from 'shiki'
import { cn } from '@/lib/cn'
import { BorderBeam } from './border-beam'

export function CodeShowcase({ files }: { files: { name: string; lang: string; code: string }[] }) {
  const [active, setActive] = useState(0)
  const [html, setHtml] = useState<string[]>([])
  const [copied, setCopied] = useState(false)

  useEffect(() => {
    let live = true
    Promise.all(
      files.map((f) =>
        codeToHtml(f.code, {
          lang: f.lang,
          themes: { light: 'github-light', dark: 'github-dark-default' },
          defaultColor: false,
        }),
      ),
    ).then((h) => live && setHtml(h))
    return () => {
      live = false
    }
  }, [files])

  const file = files[active]!
  return (
    <div className="relative overflow-hidden rounded-3xl border border-fd-border bg-fd-card">
      <BorderBeam size={260} duration={14} />
      <div className="flex items-center justify-between border-fd-border border-b px-3">
        <div className="flex">
          {files.map((f, i) => (
            <button
              key={f.name}
              type="button"
              onClick={() => setActive(i)}
              className={cn(
                'relative px-3 py-3 font-mono text-xs transition-colors',
                i === active
                  ? 'text-fd-foreground'
                  : 'text-fd-muted-foreground hover:text-fd-foreground',
              )}
            >
              {f.name}
              {i === active ? (
                <motion.span
                  layoutId="code-tab"
                  className="absolute inset-x-2 -bottom-px h-px bg-fd-foreground"
                />
              ) : null}
            </button>
          ))}
        </div>
        <button
          type="button"
          aria-label="Copy code"
          onClick={() => {
            navigator.clipboard.writeText(file.code)
            setCopied(true)
            setTimeout(() => setCopied(false), 1500)
          }}
          className="rounded-lg p-2 text-fd-muted-foreground transition hover:bg-fd-secondary hover:text-fd-foreground active:scale-95"
        >
          {copied ? <Check className="size-4 text-[var(--lk-ok)]" /> : <Copy className="size-4" />}
        </button>
      </div>
      <div
        className="lk-code overflow-x-auto p-5 font-mono text-[13px] leading-relaxed [&_pre]:!bg-transparent"
        // Shiki output from the fixed strings above (no visitor input).
        // biome-ignore lint/security/noDangerouslySetInnerHtml: trusted, static source
        dangerouslySetInnerHTML={{ __html: html[active] ?? '' }}
      />
      {html.length === 0 ? (
        <pre className="p-5 font-mono text-[13px] text-fd-muted-foreground leading-relaxed">
          {file.code}
        </pre>
      ) : null}
    </div>
  )
}
