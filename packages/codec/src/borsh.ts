// Minimal borsh: the subset LEZ's wire types use. u64/u128 travel as
// decimal strings (no BigInt: QML).
import { readUle, u64le, u128le } from './amount.ts'
import { type Bytes, concat, fromUtf8, utf8 } from './bytes.ts'

export class Writer {
  private parts: Bytes[] = []
  u8(v: number): this {
    if (!Number.isInteger(v) || v < 0 || v > 0xff) throw new Error(`u8 out of range: ${v}`)
    this.parts.push(new Uint8Array([v]))
    return this
  }
  u32(v: number): this {
    if (!Number.isInteger(v) || v < 0 || v > 0xffffffff) throw new Error(`u32 out of range: ${v}`)
    const b = new Uint8Array(4)
    new DataView(b.buffer).setUint32(0, v, true)
    this.parts.push(b)
    return this
  }
  u64(dec: string | number): this {
    this.parts.push(u64le(dec))
    return this
  }
  u128(dec: string | number): this {
    this.parts.push(u128le(dec))
    return this
  }
  /** Fixed-size bytes (no length prefix). */
  fixed(b: Bytes): this {
    this.parts.push(b)
    return this
  }
  bytes(b: Bytes): this {
    return this.u32(b.length).fixed(b)
  }
  string(s: string): this {
    return this.bytes(utf8(s))
  }
  vec<T>(xs: readonly T[], f: (w: Writer, x: T) => void): this {
    this.u32(xs.length)
    for (const x of xs) f(this, x)
    return this
  }
  option<T>(x: T | null | undefined, f: (w: Writer, x: T) => void): this {
    if (x === null || x === undefined) return this.u8(0)
    this.u8(1)
    f(this, x)
    return this
  }
  toBytes(): Bytes {
    return concat(...this.parts)
  }
}

export class Reader {
  private readonly b: Bytes
  private o = 0
  constructor(b: Bytes) {
    this.b = b
  }
  private take(n: number): Bytes {
    if (this.o + n > this.b.length) throw new Error('borsh: unexpected end of data')
    const out = this.b.subarray(this.o, this.o + n)
    this.o += n
    return out
  }
  u8(): number {
    return this.take(1)[0] as number
  }
  u32(): number {
    const t = this.take(4)
    return new DataView(t.buffer, t.byteOffset, 4).getUint32(0, true)
  }
  u64(): string {
    return readUle(this.take(8))
  }
  u128(): string {
    return readUle(this.take(16))
  }
  fixed(n: number): Bytes {
    return this.take(n).slice()
  }
  bytes(): Bytes {
    return this.fixed(this.u32())
  }
  string(): string {
    return fromUtf8(this.bytes())
  }
  vec<T>(f: (r: Reader) => T): T[] {
    const n = this.u32()
    const out: T[] = []
    for (let i = 0; i < n; i++) out.push(f(this))
    return out
  }
  option<T>(f: (r: Reader) => T): T | null {
    const tag = this.u8()
    if (tag === 0) return null
    if (tag !== 1) throw new Error('borsh: bad option tag')
    return f(this)
  }
  /** Fails on trailing bytes. */
  end(): void {
    if (this.o !== this.b.length) throw new Error('borsh: trailing bytes')
  }
}
