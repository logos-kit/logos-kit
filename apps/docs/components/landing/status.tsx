// From 21st.dev diceui/status (id 25393, MIT): https://21st.dev/@diceui/components/status
// Same anatomy (pill, pinging indicator, label) without cva/radix, in Tray colours.
import { cn } from '@/lib/cn'

const tone = {
  ok: 'border-[var(--lk-ok)]/25 bg-[var(--lk-ok)]/10 text-[var(--lk-ok)]',
  info: 'border-[var(--lk-action)]/25 bg-[var(--lk-action)]/10 text-[var(--lk-action)]',
  warn: 'border-[var(--lk-warn)]/25 bg-[var(--lk-warn)]/10 text-[var(--lk-warn)]',
  danger: 'border-[var(--lk-danger)]/25 bg-[var(--lk-danger)]/10 text-[var(--lk-danger)]',
  priv: 'border-[var(--lk-priv)]/25 bg-[var(--lk-priv)]/10 text-[var(--lk-priv)]',
  muted: 'border-fd-border bg-fd-secondary text-fd-muted-foreground',
} as const

export function Status({
  variant = 'muted',
  pulse = false,
  className,
  children,
}: {
  variant?: keyof typeof tone
  pulse?: boolean
  className?: string
  children: React.ReactNode
}) {
  return (
    <span
      className={cn(
        'inline-flex w-fit shrink-0 items-center gap-1.5 whitespace-nowrap rounded-full border px-2.5 py-1 font-medium text-xs',
        tone[variant],
        className,
      )}
    >
      <span
        className={cn(
          'relative flex size-2 shrink-0 rounded-full bg-current',
          pulse &&
            'before:absolute before:inset-0 before:animate-ping before:rounded-full before:bg-inherit',
        )}
      />
      <span className="leading-none">{children}</span>
    </span>
  )
}
