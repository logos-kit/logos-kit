// Transports carry JSON-RPC-shaped requests. `http` talks to a LEZ node;
// `basecampModule` talks to the Logos Kit wallet module (LWS-0) from QML;
// `custom` wraps anything with a `request` (an injected provider, a mock).
import { LezError, WALLET_CORE_MODULE } from '@logos-kit/protocol'
import { HttpError, RpcError, TimeoutError } from './errors.ts'
import { parseJson } from './json.ts'

export interface Transport {
  readonly type: string
  request<T = unknown>(method: string, params: unknown): Promise<T>
}

export interface HttpOptions {
  /** Per request (ms). Default 20 s. */
  timeout?: number
  /** Retries after a network error or HTTP 5xx/429 (never after an RPC error). Default 2. */
  retryCount?: number
  fetch?: typeof fetch
}

const sleep = (ms: number) => new Promise<void>((r) => setTimeout(r, ms))

export function http(url: string, options: HttpOptions = {}): Transport {
  const timeout = options.timeout ?? 20000
  const retries = options.retryCount ?? 2
  let id = 0
  return {
    type: 'http',
    async request<T>(method: string, params: unknown): Promise<T> {
      const doFetch = options.fetch ?? fetch
      const body = JSON.stringify({ jsonrpc: '2.0', id: ++id, method, params })
      for (let attempt = 0; ; attempt++) {
        const ctrl = typeof AbortController === 'undefined' ? undefined : new AbortController()
        const timer = setTimeout(() => ctrl?.abort(), timeout)
        let res: Response
        try {
          res = await doFetch(url, {
            method: 'POST',
            headers: { 'content-type': 'application/json' },
            body,
            signal: ctrl?.signal,
          })
        } catch (e) {
          clearTimeout(timer)
          if (attempt < retries) {
            await sleep(250 * 2 ** attempt)
            continue
          }
          throw ctrl?.signal.aborted ? new TimeoutError(`${method}: no answer in ${timeout} ms`) : e
        }
        clearTimeout(timer)
        if (!res.ok) {
          if ((res.status >= 500 || res.status === 429) && attempt < retries) {
            await sleep(250 * 2 ** attempt)
            continue
          }
          throw new HttpError(res.status, `${method}: HTTP ${res.status}`)
        }
        return unwrapRpc<T>(parseJson(await res.text()))
      }
    },
  }
}

function unwrapRpc<T>(msg: unknown): T {
  const m = msg as { result?: unknown; error?: { code: number; message: string; data?: unknown } }
  if (m && m.error) throw new RpcError(m.error.code, m.error.message, m.error.data)
  return m.result as T
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

/**
 * LWS-0 over a Basecamp core module: `method(paramsJson)` returns a JSON
 * payload `{"value": <LWS-0 result or its JSON text>}` or `{"error": {code, message, data}}`.
 */
export function basecampModule(options: BasecampModuleOptions): Transport {
  const module = options.module ?? WALLET_CORE_MODULE
  const timeout = options.timeout ?? 30000
  return {
    type: 'basecampModule',
    request<T>(method: string, params: unknown): Promise<T> {
      return new Promise<T>((resolve, reject) => {
        options.callModuleAsync(
          module,
          method,
          [JSON.stringify(params === undefined ? {} : params)],
          (payload) => {
            try {
              const r = (typeof payload === 'string' ? parseJson(payload) : payload) as {
                value?: unknown
                error?: { code?: number; message?: string; data?: unknown } | string
              }
              if (r && r.error !== undefined) {
                const e = r.error
                reject(
                  typeof e === 'string'
                    ? new LezError(-32603, e)
                    : new LezError(typeof e.code === 'number' ? e.code : -32603, e.message, e.data),
                )
                return
              }
              const v = r ? r.value : undefined
              resolve((typeof v === 'string' && /^[[{]/.test(v) ? parseJson(v) : v) as T)
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
