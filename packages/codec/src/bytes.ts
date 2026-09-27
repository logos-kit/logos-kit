// Byte helpers. QML-safe (ES2017, no BigInt).
import { base58, base64 } from '@scure/base'

export type Bytes = Uint8Array

const HEX = '0123456789abcdef'

export function toHex(b: Bytes): string {
  let s = ''
  for (let i = 0; i < b.length; i++) {
    const x = b[i] as number
    s += (HEX[x >> 4] as string) + (HEX[x & 15] as string)
  }
  return s
}

export function fromHex(s: string): Bytes {
  const h = s.startsWith('0x') ? s.slice(2) : s
  if (h.length % 2 !== 0 || !/^[0-9a-fA-F]*$/.test(h)) throw new Error('not hex')
  const out = new Uint8Array(h.length / 2)
  for (let i = 0; i < out.length; i++) out[i] = parseInt(h.substr(i * 2, 2), 16)
  return out
}

export function concat(...parts: Bytes[]): Bytes {
  let n = 0
  for (const p of parts) n += p.length
  const out = new Uint8Array(n)
  let o = 0
  for (const p of parts) {
    out.set(p, o)
    o += p.length
  }
  return out
}

export function equal(a: Bytes, b: Bytes): boolean {
  if (a.length !== b.length) return false
  for (let i = 0; i < a.length; i++) if (a[i] !== b[i]) return false
  return true
}

/** UTF-8 (QML has no TextEncoder unless shimmed; this needs none). */
export function utf8(s: string): Bytes {
  const out: number[] = []
  for (let i = 0; i < s.length; i++) {
    let c = s.charCodeAt(i)
    if (c >= 0xd800 && c < 0xdc00 && i + 1 < s.length) {
      const d = s.charCodeAt(i + 1)
      if (d >= 0xdc00 && d < 0xe000) {
        c = 0x10000 + ((c - 0xd800) << 10) + (d - 0xdc00)
        i++
      }
    }
    if (c < 0x80) out.push(c)
    else if (c < 0x800) out.push(0xc0 | (c >> 6), 0x80 | (c & 63))
    else if (c < 0x10000) out.push(0xe0 | (c >> 12), 0x80 | ((c >> 6) & 63), 0x80 | (c & 63))
    else
      out.push(0xf0 | (c >> 18), 0x80 | ((c >> 12) & 63), 0x80 | ((c >> 6) & 63), 0x80 | (c & 63))
  }
  return new Uint8Array(out)
}

export function fromUtf8(b: Bytes): string {
  let s = ''
  let i = 0
  while (i < b.length) {
    const c = b[i++] as number
    let cp: number
    if (c < 0x80) cp = c
    else if (c < 0xe0) cp = ((c & 31) << 6) | ((b[i++] as number) & 63)
    else if (c < 0xf0)
      cp = ((c & 15) << 12) | (((b[i++] as number) & 63) << 6) | ((b[i++] as number) & 63)
    else
      cp =
        ((c & 7) << 18) |
        (((b[i++] as number) & 63) << 12) |
        (((b[i++] as number) & 63) << 6) |
        ((b[i++] as number) & 63)
    s += String.fromCodePoint(cp)
  }
  return s
}

export const toBase58 = (b: Bytes): string => base58.encode(b)
export const fromBase58 = (s: string): Bytes => base58.decode(s)
export const toBase64 = (b: Bytes): string => base64.encode(b)
export const fromBase64 = (s: string): Bytes => base64.decode(s)
