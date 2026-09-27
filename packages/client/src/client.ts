// `createClient({ transport, chain }).extend(actions)`, viem-style.
import type { ChainId } from '@logos-kit/protocol'
import type { Transport } from './transports.ts'

export interface Client {
  readonly transport: Transport
  readonly chain: ChainId
  request<T = unknown>(method: string, params?: unknown): Promise<T>
  extend<E extends object>(fn: (client: this) => E): this & E
}

export interface ClientConfig {
  transport: Transport
  /** CAIP-2 chain, e.g. `lez:testnet`. */
  chain: ChainId
}

export function createClient(config: ClientConfig): Client {
  const base = {
    transport: config.transport,
    chain: config.chain,
    request<T>(method: string, params?: unknown): Promise<T> {
      return config.transport.request<T>(method, params === undefined ? [] : params)
    },
  }
  return withExtend(base) as Client
}

function withExtend<C extends object>(client: C): C & { extend: unknown } {
  const out = client as C & { extend: unknown }
  out.extend = (fn: (c: C) => object) => withExtend(Object.assign({}, out, fn(out)))
  return out
}
