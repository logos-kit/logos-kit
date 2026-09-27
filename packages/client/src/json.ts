// Lossless JSON: LEZ nodes send u128 balances and nonces as bare JSON
// numbers, which `JSON.parse` rounds past 2^53. Integers that don't fit a
// double exactly come back as decimal strings; everything else is standard.
// QML-safe (ES2017, no BigInt).

const WS = /[ \t\n\r]/
const LITERALS: [string, boolean | null][] = [
  ['true', true],
  ['false', false],
  ['null', null],
]

export function parseJson(text: string): unknown {
  let i = 0
  const fail = (what: string): never => {
    throw new SyntaxError(`JSON: ${what} at ${i}`)
  }
  const ws = () => {
    while (i < text.length && WS.test(text.charAt(i))) i++
  }
  const value = (): unknown => {
    ws()
    const c = text.charAt(i)
    if (c === '{') return object()
    if (c === '[') return array()
    if (c === '"') return string()
    if (c === '-' || (c >= '0' && c <= '9')) return number()
    for (const [word, v] of LITERALS) {
      if (text.startsWith(word, i)) {
        i += word.length
        return v
      }
    }
    return fail('unexpected token')
  }
  const object = (): Record<string, unknown> => {
    const out: Record<string, unknown> = {}
    i++
    ws()
    if (text.charAt(i) === '}') {
      i++
      return out
    }
    for (;;) {
      ws()
      if (text.charAt(i) !== '"') fail('expected key')
      const key = string()
      ws()
      if (text.charAt(i++) !== ':') fail('expected ":"')
      // Own data property even for "__proto__" (no prototype pollution).
      Object.defineProperty(out, key, {
        value: value(),
        enumerable: true,
        writable: true,
        configurable: true,
      })
      ws()
      const c = text.charAt(i++)
      if (c === '}') return out
      if (c !== ',') fail('expected "," or "}"')
    }
  }
  const array = (): unknown[] => {
    const out: unknown[] = []
    i++
    ws()
    if (text.charAt(i) === ']') {
      i++
      return out
    }
    for (;;) {
      out.push(value())
      ws()
      const c = text.charAt(i++)
      if (c === ']') return out
      if (c !== ',') fail('expected "," or "]"')
    }
  }
  const string = (): string => {
    const start = ++i
    let escaped = false
    while (i < text.length) {
      const c = text.charCodeAt(i)
      if (c === 34) break // "
      if (c < 0x20) fail('control character in string')
      if (c === 92) {
        // backslash
        escaped = true
        i += 2
      } else i++
    }
    if (i >= text.length) fail('unterminated string')
    const s = text.slice(start, i++)
    return escaped ? (JSON.parse(`"${s}"`) as string) : s
  }
  const digits = (): number => {
    const start = i
    while (i < text.length && text.charCodeAt(i) >= 48 && text.charCodeAt(i) <= 57) i++
    return i - start
  }
  // RFC 8259 number grammar; integers past 2^53 stay decimal strings.
  const number = (): number | string => {
    const start = i
    if (text.charAt(i) === '-') i++
    const intStart = i
    const n = digits()
    if (n === 0 || (n > 1 && text.charAt(intStart) === '0')) fail('bad number')
    let integer = true
    if (text.charAt(i) === '.') {
      integer = false
      i++
      if (digits() === 0) fail('bad number')
    }
    if (text.charAt(i) === 'e' || text.charAt(i) === 'E') {
      integer = false
      i++
      if (text.charAt(i) === '+' || text.charAt(i) === '-') i++
      if (digits() === 0) fail('bad number')
    }
    const lexeme = text.slice(start, i)
    const v = Number(lexeme)
    return integer && !Number.isSafeInteger(v) ? lexeme : v
  }
  const out = value()
  ws()
  if (i !== text.length) fail('trailing data')
  return out
}

const MAX = { u64: '18446744073709551615', u128: '340282366920938463463374607431768211455' }

/** A u64/u128 JSON value (number or lossless string) as a decimal string, range-checked. */
export function decimal(v: unknown, kind: 'u64' | 'u128' = 'u128'): string {
  let s = ''
  if (typeof v === 'string' && /^(0|[1-9][0-9]*)$/.test(v)) s = v
  else if (typeof v === 'number' && Number.isSafeInteger(v) && v >= 0) s = String(v)
  else throw new TypeError(`expected an unsigned integer, got ${JSON.stringify(v)}`)
  const max = MAX[kind]
  if (s.length > max.length || (s.length === max.length && s > max))
    throw new RangeError(`${kind} overflow: ${s}`)
  return s
}
