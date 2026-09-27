import { describe, expect, it } from 'vitest'
import {
  formatUnits,
  fromUtf8,
  NATIVE_TOKEN_PROGRAM,
  tokenTransfer,
  utf8,
  Writer,
} from '../src/index.ts'
import { signMessage } from '../src/sign.ts'

describe('input checks', () => {
  it('borsh integers refuse out-of-range values instead of wrapping', () => {
    expect(() => new Writer().u8(256)).toThrow()
    expect(() => new Writer().u32(-1)).toThrow()
    expect(() => new Writer().u32(2 ** 32)).toThrow()
    expect(() => new Writer().u32(1.5)).toThrow()
  })
  it('strict UTF-8', () => {
    const d = (bytes: number[]) => fromUtf8(new Uint8Array(bytes))
    expect(d([0xc0, 0x80])).toBe('��') // overlong NUL
    expect(d([0xed, 0xa0, 0x80])).toBe('���') // surrogate
    expect(d([0xf4, 0x90, 0x80, 0x80])).toBe('����') // > U+10FFFF
    expect(d([0xe2, 0x9c])).toBe('��') // truncated
    expect(fromUtf8(utf8('✓ 😀 é'))).toBe('✓ 😀 é')
    expect(fromUtf8(utf8('a\ud800b'))).toBe('a�b')
    expect(new TextDecoder().decode(new Uint8Array([0xe2, 0x9c, 0x93]))).toBe(d([0xe2, 0x9c, 0x93]))
  })
  it('amount decimals, token kinds, signer count', () => {
    expect(() => formatUnits('1', -1)).toThrow()
    expect(() => formatUnits('1', 1.5)).toThrow()
    expect(() => tokenTransfer('1', '1', NATIVE_TOKEN_PROGRAM, '1', 'nft' as 'fungible')).toThrow()
    const message = {
      program: NATIVE_TOKEN_PROGRAM,
      shardSelectors: [],
      nonces: ['0'],
      instructionData: new Uint8Array(),
      fee: null,
    }
    expect(() => signMessage(message, [])).toThrow(/one key per signer/)
  })
})
