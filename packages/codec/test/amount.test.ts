// The BigInt-free u128 arithmetic, checked against native BigInt (tests only
// run in Node; the code under test runs in QML too).
import { describe, expect, it } from 'vitest'
import {
  add,
  compare,
  formatUnits,
  parseUnits,
  readUle,
  toHex,
  u64le,
  u128,
  u128le,
} from '../src/index.ts'

const MAX = (1n << 128n) - 1n
const le = (v: bigint, n: number) => {
  const b = new Uint8Array(n)
  for (let i = 0; i < n; i++) b[i] = Number((v >> BigInt(8 * i)) & 255n)
  return b
}
let seed = 12345
const rand = (): bigint => {
  let v = 0n
  for (let i = 0; i < 4; i++) {
    seed = (seed * 1103515245 + 12345) & 0x7fffffff
    v = (v << 32n) | BigInt(seed)
  }
  return v & MAX
}

describe('u128 without BigInt', () => {
  it('bytes round trip against BigInt', () => {
    const values = [0n, 1n, 255n, 256n, 2n ** 53n + 1n, 2n ** 64n - 1n, 2n ** 64n, MAX]
    for (let i = 0; i < 300; i++) values.push(rand() >> BigInt(i % 128))
    for (const v of values) {
      expect(toHex(u128le(v.toString()))).toBe(toHex(le(v, 16)))
      expect(readUle(le(v, 16))).toBe(v.toString())
    }
    expect(toHex(u64le('18446744073709551615'))).toBe('ffffffffffffffff')
  })
  it('add and compare against BigInt', () => {
    for (let i = 0; i < 300; i++) {
      const a = rand() >> 1n
      const b = rand() >> 1n
      expect(add(a.toString(), b.toString())).toBe((a + b).toString())
      expect(compare(a.toString(), b.toString())).toBe(a < b ? -1 : a > b ? 1 : 0)
    }
    expect(() => add(MAX.toString(), '1')).toThrow(/overflow/)
    expect(() => u128((MAX + 1n).toString())).toThrow(/overflow/)
    expect(() => u128('01')).toThrow()
    expect(() => u128(2 ** 60)).toThrow()
  })
  it('units', () => {
    expect(formatUnits('1500000', 6)).toBe('1.5')
    expect(formatUnits('5', 6)).toBe('0.000005')
    expect(formatUnits('7', 0)).toBe('7')
    expect(parseUnits('1.5', 6)).toBe('1500000')
    expect(parseUnits('0.000005', 6)).toBe('5')
    expect(parseUnits('0', 6)).toBe('0')
    expect(() => parseUnits('1.1234567', 6)).toThrow()
  })
  it('LGO: 9 decimals, sliced, never rounded', () => {
    expect(formatUnits('0', 9)).toBe('0')
    expect(formatUnits('1', 9)).toBe('0.000000001')
    expect(formatUnits('1000000000', 9)).toBe('1')
    expect(formatUnits('1500000000', 9)).toBe('1.5')
    expect(formatUnits('18446744073709551615', 9)).toBe('18446744073.709551615')
    expect(parseUnits('0.000000001', 9)).toBe('1')
    expect(parseUnits('1.5', 9)).toBe('1500000000')
    expect(parseUnits('18446744073.709551615', 9)).toBe('18446744073709551615')
    expect(() => parseUnits('1.0000000001', 9)).toThrow()
    expect(() => parseUnits('1,5', 9)).toThrow()
    expect(() => parseUnits('abc', 9)).toThrow()
    expect(() => formatUnits('1.5', 9)).toThrow()
  })
})
