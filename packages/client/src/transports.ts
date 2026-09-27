// Transports carry JSON-RPC-shaped requests. `http` talks to a LEZ node;
// `basecampModule` talks to the Logos Kit wallet module (LWS-0) from QML;
// `custom` wraps anything with a `request` (an injected provider, a mock).
import { ErrorCode, fromIntentError, LezError, WALLET_CORE_MODULE } from '@logos-kit/protocol'
import { HttpError, RpcError, TimeoutError } from './errors.ts'
import { parseJson } from './json.ts'

export interface Transport {
  readonly type: string
  request<T = unknown>(method: string, params: unknown): Promise<T>
}

export interface HttpOptions {
  /** Per request, body included (ms). Default 20 s. */
  timeout?: number
  /**
   * Retries after a network error, a timeout or HTTP 5xx/429 (never after an
   * RPC error). Default 2. `sendTransaction` is never retried: a node that
   * accepted it but answered late would see the resend as a duplicate.
   */
  retryCount?: number
  fetch?: typeof fetch
}

const sleep = (ms: number) => new Promise<void>((r) => setTimeout(r, ms))
const NO_RETRY = ['sendTransaction']

export function http(url: string, options: HttpOptions = {}): Transport {
  const timeout = options.timeout ?? 20000
  let id = 0

  async function attempt(method: string, body: string, reqId: number): Promise<unknown> {
    const doFetch = options.fetch ?? fetch
    const ctrl = typeof AbortController === 'undefined' ? undefined : new AbortController()
    let timer: ReturnType<typeof setTimeout> | undefined
    const expired = new Promise<never>((_, reject) => {
      timer = setTimeout(() => {
        ctrl?.abort()
        reject(new TimeoutError(`${method}: no answer in ${timeout} ms`))
      }, timeout)
    })
    try {
      return await Promise.race([
        expired,
        (async () => {
          const res = await doFetch(url, {
            method: 'POST',
            headers: { 'content-type': 'application/json' },
            body,
            signal: ctrl?.signal,
          })
          if (!res.ok) throw new HttpError(res.status, `${method}: HTTP ${res.status}`)
          return unwrapRpc(parseJson(await res.text()), reqId)
        })(),
      ])
    } finally {
      clearTimeout(timer)
    }
  }

  return {
    type: 'http',
    async request<T>(method: string, params: unknown): Promise<T> {
      const reqId = ++id
      const body = JSON.stringify({ jsonrpc: '2.0', id: reqId, method, params })
      const retries = NO_RETRY.indexOf(method) >= 0 ? 0 : (options.retryCount ?? 2)
      for (let n = 0; ; n++) {
        try {
          return (await attempt(method, body, reqId)) as T
        } catch (e) {
          const transient =
            !(e instanceof RpcError) &&
            (!(e instanceof HttpError) || e.status >= 500 || e.status === 429)
          if (!transient || n >= retries) throw e
          await sleep(250 * 2 ** n)
        }
      }
    },
  }
}

function unwrapRpc(msg: unknown, id: number): unknown {
  const m = msg as {
    id?: unknown
    result?: unknown
    error?: { code: number; message: string; data?: unknown }
  }
  if (!m || typeof m !== 'object' || m.id !== id)
    throw new RpcError(-32603, 'malformed JSON-RPC response')
  if (m.error) throw new RpcError(m.error.code, m.error.message, m.error.data)
  if (!('result' in m)) throw new RpcError(-32603, 'JSON-RPC response has neither result nor error')
  return m.result
}

export function custom(provider: {
  request(args: { method: string; params: unknown }): Promise<unknown>
}): Transport {
  return {
    type: 'custom',
    request: <T>(method: string, params: unknown) =>
      provider.request({ method, params }) as Promise<T>,
  }
}

/** `logos.callModuleAsync` from Basecamp's QML bridge. */
export type CallModuleAsync = (
  module: string,
  method: string,
  args: unknown[],
  callback: (payload: string) => void,
  timeoutMs?: number,
) => void

export interface BasecampModuleOptions {
  callModuleAsync: CallModuleAsync
  /** Default `logos_kit_wallet`. */
  module?: string
  /** Default 30 s (reads). User-facing steps go through intents, not here. */
  timeout?: number
}

function moduleError(e: unknown): LezError {
  if (typeof e === 'string') return fromIntentError(e)
  const o = e as { code?: unknown; message?: unknown; data?: unknown } | null
  if (o && typeof o === 'object' && typeof o.code === 'number')
    return new LezError(o.code, typeof o.message === 'string' ? o.message : undefined, o.data)
  return new LezError(ErrorCode.Internal)
}

/**
 * LWS-0 over a Basecamp core module: `method(paramsJson)`; the module answers
 * with the JSON text `{"value": <result>}` or `{"error": {code, message, data}}`.
 */
export function basecampModule(options: BasecampModuleOptions): Transport {
  const module = options.module ?? WALLET_CORE_MODULE
  const timeout = options.timeout ?? 30000
  return {
    type: 'basecampModule',
    request<T>(method: string, params: unknown): Promise<T> {
      return new Promise<T>((resolve, reject) => {
        let done = false
        // The bridge's own timeout may never fire (module restarted): keep one here too.
        const timer = setTimeout(() => {
          if (done) return
          done = true
          reject(new TimeoutError(`${module}.${method}: no answer in ${timeout} ms`))
        }, timeout + 1000)
        options.callModuleAsync(
          module,
          method,
          [JSON.stringify(params === undefined ? {} : params)],
          (payload) => {
            if (done) return
            done = true
            clearTimeout(timer)
            try {
              const r = (typeof payload === 'string' ? parseJson(payload) : payload) as {
                value?: unknown
                error?: unknown
              } | null
              if (!r || typeof r !== 'object')
                throw new LezError(ErrorCode.Internal, 'malformed module answer')
              if ('error' in r && r.error !== undefined) reject(moduleError(r.error))
              else resolve(r.value as T)
            } catch (e) {
              reject(e)
            }
          },
          timeout,
        )
      })
    },
  }
}
