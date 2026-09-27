// u64/u128 as decimal strings, via bn.js (no native BigInt: QML).
import BN from 'bn.js'
import type { Bytes } from './bytes.ts'

const U128_MAX = new BN(1).ushln(128).subn(1)
const U64_MAX = new BN(1).ushln(64).subn(1)
const DEC = /^(0|[1-9][0-9]*)$/

function parse(dec: string | number, max: BN, what: string): BN {
  const s = String(dec)
  if (!DEC.test(s)) throw new Error(`${what}: not a decimal integer: ${s}`)
  const v = new BN(s, 10)
  if (v.gt(max)) throw new Error(`${what} overflow: ${s}`)
  return v
}

/** Validates and normalises a u128 decimal string. */
export const u128 = (dec: string | number): string => parse(dec, U128_MAX, 'u128').toString(10)
export const u64 = (dec: string | number): string => parse(dec, U64_MAX, 'u64').toString(10)

export const u128le = (dec: string | number): Bytes =>
  new Uint8Array(parse(dec, U128_MAX, 'u128').toArray('le', 16))
export const u64le = (dec: string | number): Bytes =>
  new Uint8Array(parse(dec, U64_MAX, 'u64').toArray('le', 8))
export const readUle = (b: Bytes): string => new BN(b, 'le').toString(10)

export function add(a: string, b: string): string {
  return new BN(u128(a), 10).add(new BN(u128(b), 10)).toString(10)
}

export function compare(a: string, b: string): -1 | 0 | 1 {
  return new BN(u128(a), 10).cmp(new BN(u128(b), 10))
}

/** `raw` in base units → a decimal string with `decimals` places (trailing zeros cut). */
export function formatUnits(raw: string, decimals: number): string {
  const v = new BN(u128(raw), 10)
  if (decimals === 0) return v.toString(10)
  const base = new BN(10).pow(new BN(decimals))
  const whole = v.div(base).toString(10)
  let frac = v.mod(base).toString(10)
  while (frac.length < decimals) frac = `0${frac}`
  frac = frac.replace(/0+$/, '')
  return frac ? `${whole}.${frac}` : whole
}

/** A human amount (`"1.5"`) → base units. Refuses more decimals than the asset has. */
export function parseUnits(s: string, decimals: number): string {
  const m = /^([0-9]+)(?:\.([0-9]*))?$/.exec(s.trim())
  if (!m) throw new Error(`not an amount: ${s}`)
  const f = m[2] || ''
  if (f.length > decimals) throw new Error(`more than ${decimals} decimal places: ${s}`)
  let frac = f
  while (frac.length < decimals) frac += '0'
  return u128(
    (m[1] as string) + frac === '' ? '0' : new BN((m[1] as string) + frac, 10).toString(10),
  )
}
