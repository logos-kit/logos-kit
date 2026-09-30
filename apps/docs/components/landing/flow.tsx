'use client'

// How an app reaches the wallet, drawn with the 21st.dev Animated Beam
// (dillionverma, id 919). Real marks only: the app's, Basecamp's, the
// wallet's and Logos'.
import Image from 'next/image'
import { forwardRef, useRef } from 'react'
import { cn } from '@/lib/cn'
import { AnimatedBeam } from './animated-beam'

const Node = forwardRef<
  HTMLDivElement,
  { label: string; sub: string; children: React.ReactNode; className?: string }
>(function Node({ label, sub, children, className }, ref) {
  return (
    <div className="z-10 flex flex-col items-center gap-2 text-center">
      <div
        ref={ref}
        className={cn(
          'flex size-16 items-center justify-center overflow-hidden rounded-2xl border border-fd-border bg-fd-card shadow-[0_8px_30px_-12px_rgb(0_0_0/0.45)] md:size-[4.5rem]',
          className,
        )}
      >
        {children}
      </div>
      <div className="font-medium text-xs md:text-sm">{label}</div>
      <div className="-mt-1.5 text-[11px] text-fd-muted-foreground md:text-xs">{sub}</div>
    </div>
  )
})

export function Flow() {
  const box = useRef<HTMLDivElement>(null)
  const app = useRef<HTMLDivElement>(null)
  const shell = useRef<HTMLDivElement>(null)
  const wallet = useRef<HTMLDivElement>(null)
  const chain = useRef<HTMLDivElement>(null)
  return (
    <div
      ref={box}
      className="relative flex w-full items-start justify-between gap-2 px-1 py-10 text-fd-foreground"
    >
      <Node ref={app} label="Your app" sub="LogosKit SDK">
        <Image
          src="/logos/logos-kit-testimonials.png"
          alt=""
          width={144}
          height={144}
          className="size-full"
        />
      </Node>
      <Node ref={shell} label="Basecamp" sub="attests the app" className="bg-black">
        <Image src="/logos/basecamp.svg" alt="" width={40} height={21} />
      </Node>
      <Node ref={wallet} label="Logos Kit" sub="keys · approvals">
        <Image
          src="/logos/logos-kit-wallet.png"
          alt=""
          width={144}
          height={144}
          className="size-full"
        />
      </Node>
      <Node ref={chain} label="LEZ" sub="sequencer" className="bg-black">
        <Image src="/logos-mark-white.svg" alt="" width={25} height={28} />
      </Node>
      <AnimatedBeam containerRef={box} fromRef={app} toRef={shell} duration={4} />
      <AnimatedBeam containerRef={box} fromRef={shell} toRef={wallet} duration={4} delay={0.6} />
      <AnimatedBeam containerRef={box} fromRef={wallet} toRef={chain} duration={4} delay={1.2} />
      <AnimatedBeam
        containerRef={box}
        fromRef={app}
        toRef={wallet}
        curvature={-70}
        reverse
        duration={5}
        delay={2}
        gradientStartColor="var(--lk-ok)"
        gradientStopColor="var(--lk-action)"
      />
    </div>
  )
}
