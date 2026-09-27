// Backoff polling that pauses while the page (or QML view) is hidden.
import { TimeoutError } from './errors.ts'

export interface PollOptions {
  /** Give up after this much *visible* time (ms). Default 120 s. */
  timeout?: number
  /** First interval (ms). Default 500; ×1.5 up to `maxInterval`. */
  interval?: number
  maxInterval?: number
  /** While this returns false, nothing is requested and the timeout is paused. */
  isVisible?: () => boolean
  /** Checked before every probe; `true` ends the poll with `undefined`. */
  shouldStop?: () => boolean
}

const sleep = (ms: number) => new Promise<void>((r) => setTimeout(r, ms))

/**
 * Call `probe` until it returns a value that isn't `undefined` (or
 * `shouldStop` says so: then resolves `undefined`).
 */
export async function poll<T>(
  probe: () => Promise<T | undefined>,
  what: string,
  o: PollOptions = {},
): Promise<T | undefined> {
  const budget = o.timeout ?? 120000
  let spent = 0
  let wait = o.interval ?? 500
  const max = o.maxInterval ?? 5000
  for (;;) {
    if (o.shouldStop?.()) return undefined
    const visible = !o.isVisible || o.isVisible()
    if (visible) {
      const v = await probe()
      if (v !== undefined) return v
      if (spent >= budget) throw new TimeoutError(`${what}: not done in ${budget} ms`)
    }
    const step = visible ? Math.min(wait, Math.max(0, budget - spent)) || wait : wait
    await sleep(step)
    if (visible) {
      spent += step
      wait = Math.min(max, Math.round(wait * 1.5))
    }
  }
}

/** `poll` without `shouldStop`: always a value or a TimeoutError. */
export async function pollValue<T>(
  probe: () => Promise<T | undefined>,
  what: string,
  o?: PollOptions,
): Promise<T> {
  const v = await poll(probe, what, o && { ...o, shouldStop: undefined })
  if (v === undefined) throw new TimeoutError(`${what}: stopped`)
  return v
}
