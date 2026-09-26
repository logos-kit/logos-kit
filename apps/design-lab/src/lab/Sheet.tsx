import { ArrowLeft, X } from 'lucide-react'
import { AnimatePresence, motion, useReducedMotion } from 'motion/react'
import type { ReactNode } from 'react'
import useMeasure from 'react-use-measure'

// Content-height sheet. Height follows the measured step (Family's tray rule),
// steps swap with depth (ConnectKit: forward enters from 1.08x, back reverses),
// and the close control becomes Back after the first step.
export function Sheet({
  open,
  stepKey,
  dir,
  isFirst,
  onClose,
  onBack,
  busy,
  children,
  floating,
}: {
  open: boolean
  stepKey: string
  dir: 1 | -1
  isFirst: boolean
  onClose: () => void
  onBack: () => void
  busy?: boolean
  children: ReactNode
  /** Tray style: detached from the edges. */
  floating?: boolean
}) {
  const [ref, bounds] = useMeasure()
  const reduce = useReducedMotion()
  return (
    <AnimatePresence>
      {open && (
        <motion.div
          className="absolute inset-0 z-30 flex flex-col justify-end"
          initial={{ opacity: 1 }}
          exit={{ opacity: 1 }}
        >
          <motion.button
            type="button"
            aria-label="Close"
            className="absolute inset-0 cursor-default"
            style={{ background: 'rgba(0,0,0,0.45)', backdropFilter: 'blur(6px)' }}
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={() => !busy && onClose()}
          />
          <motion.div
            role="dialog"
            aria-modal="true"
            className="relative overflow-hidden"
            style={{
              background: 'var(--surface)',
              borderRadius: floating ? 'var(--r-sheet)' : 'var(--r-sheet) var(--r-sheet) 0 0',
              margin: floating ? 10 : 0,
              boxShadow: '0 -8px 40px rgba(0,0,0,0.35)',
              color: 'var(--text)',
            }}
            initial={{ y: '100%' }}
            animate={{ y: 0, height: bounds.height || 'auto' }}
            exit={{ y: '110%' }}
            transition={
              reduce
                ? { duration: 0 }
                : {
                    y: { duration: 0.3, ease: [0.15, 1.15, 0.6, 1] },
                    height: { duration: 0.2, ease: [0.25, 0.1, 0.25, 1] },
                  }
            }
          >
            <div ref={ref}>
              <div className="flex items-center justify-between px-5 pt-4">
                <button
                  type="button"
                  aria-label={isFirst ? 'Close' : 'Back'}
                  disabled={busy}
                  onClick={isFirst ? onClose : onBack}
                  className="grid size-8 place-items-center rounded-full transition-colors disabled:opacity-30"
                  style={{ background: 'var(--surface2)', color: 'var(--text2)' }}
                >
                  <AnimatePresence mode="wait" initial={false}>
                    <motion.span
                      key={isFirst ? 'x' : 'back'}
                      initial={{ rotate: -90, opacity: 0 }}
                      animate={{ rotate: 0, opacity: 1 }}
                      exit={{ rotate: 90, opacity: 0 }}
                      transition={{ duration: 0.15 }}
                    >
                      {isFirst ? <X size={15} /> : <ArrowLeft size={15} />}
                    </motion.span>
                  </AnimatePresence>
                </button>
                <span className="h-1 w-9 rounded-full" style={{ background: 'var(--line)' }} />
                <span className="size-8" />
              </div>
              <AnimatePresence mode="popLayout" initial={false} custom={dir}>
                <motion.div
                  key={stepKey}
                  custom={dir}
                  variants={{
                    enter: (d: number) => ({ opacity: 0, scale: d > 0 ? 1.08 : 0.94 }),
                    center: { opacity: 1, scale: 1 },
                    exit: (d: number) => ({ opacity: 0, scale: d > 0 ? 0.94 : 1.08 }),
                  }}
                  initial="enter"
                  animate="center"
                  exit="exit"
                  transition={{ duration: reduce ? 0 : 0.2, ease: [0.25, 0.1, 0.25, 1] }}
                  className="px-5 pb-5 pt-2"
                >
                  {children}
                </motion.div>
              </AnimatePresence>
            </div>
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  )
}
