import Image from 'next/image'
import { cn } from '@/lib/cn'

/**
 * A real wallet screen (rendered from the QML wallet) in a dark device frame:
 * the one high-contrast moment on the light page, as on Family's and Ctrl's
 * sites (Refero: family.co, ctrl.xyz).
 */
export function Phone({
  src,
  alt,
  className,
  priority,
}: {
  src: string
  alt: string
  className?: string
  priority?: boolean
}) {
  return (
    <div
      className={cn(
        'relative w-[260px] shrink-0 rounded-[46px] bg-[#0a0a0c] p-[9px] ring-1 ring-black/10 dark:ring-white/12',
        className,
      )}
    >
      <div className="overflow-hidden rounded-[38px] bg-black">
        <Image
          src={src}
          alt={alt}
          width={960}
          height={1386}
          priority={priority}
          sizes="260px"
          className="block h-auto w-full"
        />
      </div>
    </div>
  )
}
