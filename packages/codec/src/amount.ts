// u64/u128 as decimal strings, with no BigInt (QML) and no bignum library:
// the only arithmetic LEZ amounts need is decimal ↔ little-endian bytes,
// comparison and addition. Unit formatting is string work.
import type { Bytes } from './bytes.ts'

const U128_MAX = '340282366920938463463374607431768211455'
const U64_MAX = '18446744073709551615'
const DEC = /^(0|[1-9][0-9]*)$/

function cmp(a: string, b: string): -1 | 0 | 1 {
  if (a.length !== b.length) return a.length < b.length ? -1 : 1
  return a < b ? -1 : a > b ? 1 : 0
}

function parse(dec: string | number, max: string, what: string): string {
  const s = typeof dec === 'number' ? (Number.isSafeInteger(dec) ? String(dec) : '') : dec
  if (!DEC.test(s)) throw new Error(`${what}: not a decimal integer: ${dec}`)
  if (cmp(s, max) > 0) throw new Error(`${what} overflow: ${s}`)
  return s
}

/** Validates and normalises a u128 decimal string. */
export const u128 = (dec: string | number): string => parse(dec, U128_MAX, 'u128')
export const u64 = (dec: string | number): string => parse(dec, U64_MAX, 'u64')

/** Decimal → `n` little-endian bytes (repeated division by 256). */
function toLe(dec: string, n: number): Bytes {
  const out = new Uint8Array(n)
  let digits = dec.split('').map(Number)
  for (let i = 0; i < n && !(digits.length === 1 && digits[0] === 0); i++) {
    const next: number[] = []
    let rem = 0
    for (const d of digits) {
      const cur = rem * 10 + d
      const q = Math.floor(cur / 256)
      rem = cur % 256
      if (next.length || q) next.push(q)
    }
    out[i] = rem
    digits = next.length ? next : [0]
  }
  return out
}

export const u128le = (dec: string | number): Bytes => toLe(u128(dec), 16)
export const u64le = (dec: string | number): Bytes => toLe(u64(dec), 8)

/** Little-endian bytes → decimal (Horner over base 10^7 limbs). */
export function readUle(b: Bytes): string {
  const BASE = 10000000
  const limbs = [0] // least significant first
  for (let i = b.length - 1; i >= 0; i--) {
    let carry = b[i] as number
    for (let j = 0; j < limbs.length; j++) {
      const v = (limbs[j] as number) * 256 + carry
      limbs[j] = v % BASE
      carry = Math.floor(v / BASE)
    }
    while (carry) {
      limbs.push(carry % BASE)
      carry = Math.floor(carry / BASE)
    }
  }
  let s = String(limbs[limbs.length - 1])
  for (let j = limbs.length - 2; j >= 0; j--) {
    const part = String(limbs[j])
    s += '0000000'.slice(part.length) + part
  }
  return s
}

export function add(a: string, b: string): string {
  const x = u128(a)
  const y = u128(b)
  let out = ''
  let carry = 0
  for (let i = x.length - 1, j = y.length - 1; i >= 0 || j >= 0 || carry; i--, j--) {
    const s = (i >= 0 ? Number(x[i]) : 0) + (j >= 0 ? Number(y[j]) : 0) + carry
    out = String(s % 10) + out
    carry = s >= 10 ? 1 : 0
  }
  return u128(out)
}

export const compare = (a: string, b: string): -1 | 0 | 1 => cmp(u128(a), u128(b))

/** `raw` in base units → a decimal string with `decimals` places (trailing zeros cut). */
export function formatUnits(raw: string, decimals: number): string {
  const v = u128(raw)
  if (decimals === 0) return v
  const padded = v.length <= decimals ? '0'.repeat(decimals - v.length + 1) + v : v
  const whole = padded.slice(0, padded.length - decimals)
  const frac = padded.slice(padded.length - decimals).replace(/0+$/, '')
  return frac ? `${whole}.${frac}` : whole
}

/** A human amount (`"1.5"`) → base units. Refuses more decimals than the asset has. */
export function parseUnits(s: string, decimals: number): string {
  const m = /^([0-9]+)(?:\.([0-9]*))?$/.exec(s.trim())
  if (!m) throw new Error(`not an amount: ${s}`)
  const f = m[2] || ''
  if (f.length > decimals) throw new Error(`more than ${decimals} decimal places: ${s}`)
  const digits = ((m[1] as string) + f + '0'.repeat(decimals - f.length)).replace(
    /^0+(?=[0-9])/,
    '',
  )
  return u128(digits)
}
