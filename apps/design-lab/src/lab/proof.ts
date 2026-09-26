import { useCallback, useEffect, useRef, useState } from 'react'
import { DEMO_SPEEDUP, REAL_PROOF_SECONDS } from './data'

export type ProofPhase = 'preparing' | 'proving' | 'submitting' | 'waiting' | 'done'

export type ProofState = {
  phase: ProofPhase
  /** 0..1 over the whole flow. */
  pct: number
  /** Seconds left in real time (what the product would show). */
  realLeft: number
  /** Simulated proving segments, for the instrument view. */
  segment: number
  segments: number
}

// Real-time phase boundaries (seconds), totalling the measured 337 s.
const PHASES: [ProofPhase, number][] = [
  ['preparing', 4],
  ['proving', 318],
  ['submitting', 323],
  ['waiting', REAL_PROOF_SECONDS],
]
const SEGMENTS = 61

function at(realElapsed: number): ProofState {
  const t = Math.min(realElapsed, REAL_PROOF_SECONDS)
  const phase =
    t >= REAL_PROOF_SECONDS ? 'done' : (PHASES.find(([, end]) => t < end)?.[0] ?? 'waiting')
  const provingPct = Math.min(1, Math.max(0, (t - 4) / (318 - 4)))
  return {
    phase,
    pct: t / REAL_PROOF_SECONDS,
    realLeft: Math.max(0, Math.round(REAL_PROOF_SECONDS - t)),
    segment: Math.min(SEGMENTS, Math.floor(provingPct * SEGMENTS)),
    segments: SEGMENTS,
  }
}

/** Drives one private send through the measured phases at demo speed. */
export function useProof(onDone: () => void) {
  const [state, setState] = useState<ProofState | null>(null)
  const [running, setRunning] = useState(false)
  const started = useRef<number | null>(null)
  const done = useRef(onDone)
  done.current = onDone

  useEffect(() => {
    if (!running) return
    const id = window.setInterval(() => {
      const real = ((performance.now() - (started.current ?? 0)) / 1000) * DEMO_SPEEDUP
      const next = at(real)
      setState(next)
      if (next.phase === 'done') {
        window.clearInterval(id)
        started.current = null
        setRunning(false)
        done.current()
      }
    }, 100)
    return () => window.clearInterval(id)
  }, [running])

  const start = useCallback(() => {
    started.current = performance.now()
    setState(at(0))
    setRunning(true)
  }, [])
  const reset = useCallback(() => {
    started.current = null
    setRunning(false)
    setState(null)
  }, [])
  return { proof: state, start, reset }
}

export function formatLeft(s: number) {
  if (s <= 0) return 'finishing'
  if (s < 60) return `${s} s left`
  const m = Math.floor(s / 60)
  const r = s % 60
  return `${m}:${String(r).padStart(2, '0')} left`
}

export const PHASE_LABEL: Record<ProofPhase, string> = {
  preparing: 'Preparing',
  proving: 'Proving on this device',
  submitting: 'Submitting',
  waiting: 'Waiting for block',
  done: 'Sent privately',
}
