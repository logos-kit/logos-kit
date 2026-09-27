import { describe, expect, it } from 'vitest'
import {
  qmlColor,
  qmlFont,
  qmlTokensModule,
  toQmlTokens,
  trayDark,
  trayLight,
} from '../src/index.ts'

describe('QML tokens', () => {
  it('converts colours and fonts', () => {
    expect(qmlColor('rgba(107,95,255,0.12)')).toBe('#1f6b5fff')
    expect(qmlColor('#FFF')).toBe('#ffffff')
    expect(qmlFont('"Onest", ui-sans-serif, sans-serif')).toBe('Onest')
    const d = toQmlTokens(trayDark)
    expect(d.dark).toBe(true)
    expect(d.line).toBe('#12ffffff')
    expect(toQmlTokens(trayLight).rBtn).toBe(999)
  })
  it('every token set has the same keys and valid colours', () => {
    expect(Object.keys(trayDark).sort()).toEqual(Object.keys(trayLight).sort())
    for (const v of Object.values(toQmlTokens(trayDark))) {
      if (typeof v === 'string' && v.startsWith('#'))
        expect(v).toMatch(/^#([0-9a-f]{6}|[0-9a-f]{8})$/)
    }
    expect(qmlTokensModule()).toMatch(/^\.pragma library\n/)
  })
})
