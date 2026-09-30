'use client'

// From 21st.dev dillionverma/animated-beam (id 919, Magic UI, MIT):
// https://21st.dev/@dillionverma/components/animated-beam
// A light travelling along a curved path between two elements. motion/react.
import { motion } from 'motion/react'
import { type RefObject, useEffect, useId, useState } from 'react'
import { cn } from '@/lib/cn'

export function AnimatedBeam({
  className,
  containerRef,
  fromRef,
  toRef,
  curvature = 0,
  reverse = false,
  duration = 5,
  delay = 0,
  pathColor = 'currentColor',
  pathWidth = 2,
  pathOpacity = 0.15,
  gradientStartColor = 'var(--lk-action)',
  gradientStopColor = 'var(--lk-priv)',
}: {
  className?: string
  containerRef: RefObject<HTMLElement | null>
  fromRef: RefObject<HTMLElement | null>
  toRef: RefObject<HTMLElement | null>
  curvature?: number
  reverse?: boolean
  duration?: number
  delay?: number
  pathColor?: string
  pathWidth?: number
  pathOpacity?: number
  gradientStartColor?: string
  gradientStopColor?: string
}) {
  const id = useId()
  const [d, setD] = useState('')
  const [size, setSize] = useState({ width: 0, height: 0 })
  const x = reverse
    ? { x1: ['90%', '-10%'], x2: ['100%', '0%'] }
    : { x1: ['10%', '110%'], x2: ['0%', '100%'] }

  useEffect(() => {
    const update = () => {
      const c = containerRef.current
      const a = fromRef.current
      const b = toRef.current
      if (!c || !a || !b) return
      const rc = c.getBoundingClientRect()
      const ra = a.getBoundingClientRect()
      const rb = b.getBoundingClientRect()
      setSize({ width: rc.width, height: rc.height })
      const sx = ra.left - rc.left + ra.width / 2
      const sy = ra.top - rc.top + ra.height / 2
      const ex = rb.left - rc.left + rb.width / 2
      const ey = rb.top - rc.top + rb.height / 2
      setD(`M ${sx},${sy} Q ${(sx + ex) / 2},${sy - curvature} ${ex},${ey}`)
    }
    const ro = new ResizeObserver(update)
    if (containerRef.current) ro.observe(containerRef.current)
    update()
    return () => ro.disconnect()
  }, [containerRef, fromRef, toRef, curvature])

  return (
    <svg
      aria-hidden
      fill="none"
      width={size.width}
      height={size.height}
      viewBox={`0 0 ${size.width} ${size.height}`}
      className={cn('pointer-events-none absolute top-0 left-0 transform-gpu', className)}
    >
      <path
        d={d}
        stroke={pathColor}
        strokeWidth={pathWidth}
        strokeOpacity={pathOpacity}
        strokeLinecap="round"
      />
      <path d={d} stroke={`url(#${id})`} strokeWidth={pathWidth} strokeLinecap="round" />
      <defs>
        <motion.linearGradient
          id={id}
          gradientUnits="userSpaceOnUse"
          initial={{ x1: '0%', x2: '0%', y1: '0%', y2: '0%' }}
          animate={{ x1: x.x1, x2: x.x2, y1: ['0%', '0%'], y2: ['0%', '0%'] }}
          transition={{
            delay,
            duration,
            ease: [0.16, 1, 0.3, 1],
            repeat: Number.POSITIVE_INFINITY,
          }}
        >
          <stop stopColor={gradientStartColor} stopOpacity="0" />
          <stop stopColor={gradientStartColor} />
          <stop offset="32.5%" stopColor={gradientStopColor} />
          <stop offset="100%" stopColor={gradientStopColor} stopOpacity="0" />
        </motion.linearGradient>
      </defs>
    </svg>
  )
}
