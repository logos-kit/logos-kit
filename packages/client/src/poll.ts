// Backoff polling that pauses while the page (or QML view) is hidden.
import { TimeoutError } from './errors.ts'

export interface PollOptions {
  /** Give up after this long (ms). Default 120 s. */
  timeout?: number
  /** First interval (ms). Default 500; ×1.5 up to `maxInterval`. */
  interval?: number
  maxInterval?: number
  /** While this returns false, no requests are made (the deadline still runs). */
  isVisible?: () => boolean
}

const sleep = (ms: number) => new Promise<void>((r) => setTimeout(r, ms))

/** Call `probe` until it returns a value that isn't `undefined`. */
export async function poll<T>(
  probe: () => Promise<T | undefined>,
  what: string,
  o: PollOptions = {},
): Promise<T> {
  const deadline = Date.now() + (o.timeout ?? 120000)
  let wait = o.interval ?? 500
  const max = o.maxInterval ?? 5000
  for (;;) {
    if (!o.isVisible || o.isVisible()) {
      const v = await probe()
      if (v !== undefined) return v
    }
    if (Date.now() + wait > deadline)
      throw new TimeoutError(`${what}: not done in ${o.timeout ?? 120000} ms`)
    await sleep(wait)
    wait = Math.min(max, Math.round(wait * 1.5))
  }
}
