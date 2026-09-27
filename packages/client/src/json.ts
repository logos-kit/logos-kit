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
    let raw = false
    while (i < text.length) {
      const c = text.charAt(i)
      if (c === '"') break
      if (c === '\\') {
        raw = true
        i += 2
      } else i++
    }
    if (i >= text.length) fail('unterminated string')
    const s = text.slice(start, i++)
    return raw ? (JSON.parse(`"${s}"`) as string) : s
  }
  const number = (): number | string => {
    const start = i
    if (text.charAt(i) === '-') i++
    while (i < text.length && /[0-9]/.test(text.charAt(i))) i++
    let integer = true
    if (text.charAt(i) === '.') {
      integer = false
      i++
      while (i < text.length && /[0-9]/.test(text.charAt(i))) i++
    }
    if (text.charAt(i) === 'e' || text.charAt(i) === 'E') {
      integer = false
      i++
      if (text.charAt(i) === '+' || text.charAt(i) === '-') i++
      while (i < text.length && /[0-9]/.test(text.charAt(i))) i++
    }
    const lexeme = text.slice(start, i)
    const n = Number(lexeme)
    if (Number.isNaN(n) || lexeme === '-') fail('bad number')
    return integer && !Number.isSafeInteger(n) ? lexeme : n
  }
  const out = value()
  ws()
  if (i !== text.length) fail('trailing data')
  return out
}

/** A u64/u128 JSON value (number or lossless string) as a decimal string. */
export function decimal(v: unknown): string {
  if (typeof v === 'string' && /^[0-9]+$/.test(v)) return v
  if (typeof v === 'number' && Number.isSafeInteger(v) && v >= 0) return String(v)
  throw new TypeError(`expected an unsigned integer, got ${JSON.stringify(v)}`)
}
