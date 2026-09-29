import Image from 'next/image'
import { cn } from '@/lib/cn'
import manifest from '@/lib/shots.json'

type Entry = {
  kind: 'panel' | 'window'
  light: boolean
  width: number
  height: number
  alt: string
}
const shots = manifest as Record<string, Entry>

export type ShotName = keyof typeof manifest

/**
 * A product screenshot from `public/shots` (made by `pnpm shots`), framed the
 * same way everywhere: panels sit on their own surface inside a soft
 * backdrop, Basecamp windows get a rounded edge and a deep shadow.
 */
export function Shot({
  name,
  caption,
  className,
  priority,
  width,
}: {
  name: ShotName
  caption?: React.ReactNode
  className?: string
  priority?: boolean
  /** Display width cap in px (panels default to 380). */
  width?: number
}) {
  const s = shots[name]
  if (!s)
    throw new Error(`unknown shot ${name}: add it to scripts/shots.config.mjs and run pnpm shots`)
  const panel = s.kind === 'panel'
  const img = (
    <Image
      src={`/shots/${name}.webp`}
      alt={s.alt}
      width={s.width}
      height={s.height}
      priority={priority}
      sizes={panel ? '(max-width: 640px) 90vw, 380px' : '(max-width: 1024px) 100vw, 1000px'}
      className="block h-auto w-full"
    />
  )
  return (
    <figure className={cn('not-prose my-6', className)}>
      {panel ? (
        <div className="lk-backdrop flex justify-center rounded-[28px] border border-fd-border px-4 py-8 sm:px-10">
          <div
            className={cn(
              'overflow-hidden rounded-[26px] p-3 shadow-[0_24px_60px_-20px_rgb(0_0_0/0.55),0_0_0_1px_rgb(255_255_255/0.06)]',
              s.light ? 'bg-[#ebebef]' : 'bg-black',
            )}
            style={{ width: '100%', maxWidth: width ?? 380 }}
          >
            {img}
          </div>
        </div>
      ) : (
        <div
          className="overflow-hidden rounded-2xl border border-fd-border bg-black shadow-[0_30px_80px_-30px_rgb(0_0_0/0.6)]"
          style={width ? { maxWidth: width } : undefined}
        >
          {img}
        </div>
      )}
      {caption ? (
        <figcaption className="mt-3 text-center text-fd-muted-foreground text-sm">
          {caption}
        </figcaption>
      ) : null}
    </figure>
  )
}
