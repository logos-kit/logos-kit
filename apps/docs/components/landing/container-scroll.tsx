'use client'

// From 21st.dev manuarora700/container-scroll-animation (id 1081, Aceternity UI):
// https://21st.dev/@manuarora700/components/container-scroll-animation
// The product tilts flat as you scroll. Tray frame colours; motion/react;
// honours prefers-reduced-motion (no tilt).
import { type MotionValue, motion, useReducedMotion, useScroll, useTransform } from 'motion/react'
import { useEffect, useRef, useState } from 'react'

export function ContainerScroll({
  title,
  children,
}: {
  title: React.ReactNode
  children: React.ReactNode
}) {
  const ref = useRef<HTMLDivElement>(null)
  const { scrollYProgress } = useScroll({ target: ref })
  const reduce = useReducedMotion()
  const [mobile, setMobile] = useState(false)

  useEffect(() => {
    const check = () => setMobile(window.innerWidth <= 768)
    check()
    window.addEventListener('resize', check)
    return () => window.removeEventListener('resize', check)
  }, [])

  const rotate = useTransform(scrollYProgress, [0, 1], reduce ? [0, 0] : [20, 0])
  const scale = useTransform(scrollYProgress, [0, 1], mobile ? [0.92, 1] : [1.05, 1])
  const translate = useTransform(scrollYProgress, [0, 1], reduce || mobile ? [0, 0] : [0, -100])

  return (
    <div
      ref={ref}
      className="relative flex items-start justify-center px-2 pt-10 pb-6 md:h-[74rem] md:items-center md:p-16"
    >
      <div className="relative w-full py-6 md:py-24" style={{ perspective: '1000px' }}>
        <motion.div style={{ translateY: translate }} className="mx-auto max-w-5xl text-center">
          {title}
        </motion.div>
        <Frame rotate={rotate} scale={scale}>
          {children}
        </Frame>
      </div>
    </div>
  )
}

function Frame({
  rotate,
  scale,
  children,
}: {
  rotate: MotionValue<number>
  scale: MotionValue<number>
  children: React.ReactNode
}) {
  return (
    <motion.div
      style={{
        rotateX: rotate,
        scale,
        boxShadow:
          '0 0 #0000004d, 0 9px 20px #0000004a, 0 37px 37px #00000042, 0 84px 50px #00000026, 0 149px 60px #0000000a, 0 233px 65px #00000003',
      }}
      className="mx-auto mt-10 w-full max-w-5xl rounded-[30px] border border-white/10 bg-[#161618] p-2 md:mt-14 md:p-3"
    >
      <div className="h-full w-full overflow-hidden rounded-[22px] bg-black">{children}</div>
    </motion.div>
  )
}
