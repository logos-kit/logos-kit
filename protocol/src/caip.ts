// QML-safe module: ES2017 only. Only simple, non-ES2018 regexes.

export type ChainIdString = string

export type ParsedChainId = { namespace: string; reference: string }

const CHAIN_RE = /^([-a-z0-9]{3,8}):([-_a-zA-Z0-9]{1,32})$/

/** Parse a CAIP-2 chain id ("lez:testnet" → { namespace: "lez", reference: "testnet" }). */
export function parseChainId(chain: string): ParsedChainId | null {
  const m = CHAIN_RE.exec(chain)
  if (!m || m[1] === undefined || m[2] === undefined) return null
  return { namespace: m[1], reference: m[2] }
}

export function isLezChain(chain: string): boolean {
  const parsed = parseChainId(chain)
  return parsed !== null && parsed.namespace === 'lez'
}

/** CAIP-10 account id for a public LEZ account ("lez:testnet:<base58>"). */
export function toCaip10(chain: string, accountId: string): string {
  return `${chain}:${accountId}`
}

const BASE58_RE = /^[1-9A-HJ-NP-Za-km-z]{32,44}$/

export function isAccountId(value: string): boolean {
  return BASE58_RE.test(value)
}

export function isPrivateHandle(value: string): boolean {
  return /^pvt_[A-Za-z0-9_-]{16,64}$/.test(value)
}
