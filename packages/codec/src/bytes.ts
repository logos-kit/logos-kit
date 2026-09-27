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

/** UTF-8 (QML has no TextEncoder unless shimmed). Lone surrogates become U+FFFD. */
export function utf8(s: string): Bytes {
  const out: number[] = []
  for (let i = 0; i < s.length; i++) {
    let c = s.charCodeAt(i)
    if (c >= 0xd800 && c < 0xe000) {
      const d = i + 1 < s.length ? s.charCodeAt(i + 1) : 0
      if (c < 0xdc00 && d >= 0xdc00 && d < 0xe000) {
        c = 0x10000 + ((c - 0xd800) << 10) + (d - 0xdc00)
        i++
      } else c = 0xfffd
    }
    if (c < 0x80) out.push(c)
    else if (c < 0x800) out.push(0xc0 | (c >> 6), 0x80 | (c & 63))
    else if (c < 0x10000) out.push(0xe0 | (c >> 12), 0x80 | ((c >> 6) & 63), 0x80 | (c & 63))
    else
      out.push(0xf0 | (c >> 18), 0x80 | ((c >> 12) & 63), 0x80 | ((c >> 6) & 63), 0x80 | (c & 63))
  }
  return new Uint8Array(out)
}

/**
 * Strict UTF-8 decoding: malformed, overlong, surrogate and out-of-range
 * sequences become U+FFFD (per bad byte), never a lookalike character.
 */
export function fromUtf8(b: Bytes): string {
  let s = ''
  let i = 0
  const cont = (k: number) => i + k < b.length && ((b[i + k] as number) & 0xc0) === 0x80
  while (i < b.length) {
    const c = b[i] as number
    let n = 0
    let cp = 0xfffd
    if (c < 0x80) {
      cp = c
      n = 1
    } else if (c >= 0xc2 && c < 0xe0 && cont(1)) {
      cp = ((c & 31) << 6) | ((b[i + 1] as number) & 63)
      n = 2
    } else if (c >= 0xe0 && c < 0xf0 && cont(1) && cont(2)) {
      cp = ((c & 15) << 12) | (((b[i + 1] as number) & 63) << 6) | ((b[i + 2] as number) & 63)
      n = cp < 0x800 || (cp >= 0xd800 && cp < 0xe000) ? 0 : 3
    } else if (c >= 0xf0 && c < 0xf5 && cont(1) && cont(2) && cont(3)) {
      cp =
        ((c & 7) << 18) |
        (((b[i + 1] as number) & 63) << 12) |
        (((b[i + 2] as number) & 63) << 6) |
        ((b[i + 3] as number) & 63)
      n = cp < 0x10000 || cp > 0x10ffff ? 0 : 4
    }
    if (n === 0) {
      s += '\ufffd'
      i++
    } else {
      s += String.fromCodePoint(cp)
      i += n
    }
  }
  return s
}

export const toBase58 = (b: Bytes): string => base58.encode(b)
export const fromBase58 = (s: string): Bytes => base58.decode(s)
export const toBase64 = (b: Bytes): string => base64.encode(b)
export const fromBase64 = (s: string): Bytes => base64.decode(s)
