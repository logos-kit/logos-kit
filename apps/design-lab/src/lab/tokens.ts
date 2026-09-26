// Three product directions. Colour roles, not a palette: `private` is used only
// for private state, `action` for public/neutral actions (RainbowKit's purple
// #7A70FF and blue #3898FF, per the maintainer's colour rule).
export type DirectionId = 'veil' | 'tray' | 'ledger'

export type Tokens = {
  bg: string
  surface: string
  surface2: string
  line: string
  text: string
  text2: string
  text3: string
  private: string
  privateSoft: string
  privateText: string
  action: string
  actionText: string
  ok: string
  warn: string
  danger: string
  island: string
  font: string
  numFont: string
  monoFont: string
  rSheet: number
  rCard: number
  rBtn: number
  rRow: number
  scheme: 'dark' | 'light'
}

export type Direction = {
  id: DirectionId
  letter: 'A' | 'B' | 'C'
  name: string
  concept: string
  lineage: string
  tokens: Tokens
  /** Tray only: its dark variant. */
  dark?: Tokens
}

const veil: Tokens = {
  bg: '#0b0a0f',
  surface: '#15131b',
  surface2: '#1d1b25',
  line: 'rgba(255,255,255,0.07)',
  text: '#f5f3fa',
  text2: '#a7a3b5',
  text3: '#6d6979',
  private: '#7a70ff',
  privateSoft: 'rgba(122,112,255,0.16)',
  privateText: '#c4bfff',
  action: '#3898ff',
  actionText: '#ffffff',
  ok: '#4bd166',
  warn: '#ffd641',
  danger: '#ff6257',
  island: '#000000',
  font: '"Instrument Sans", ui-sans-serif, sans-serif',
  numFont: '"Instrument Sans", ui-sans-serif, sans-serif',
  monoFont: '"JetBrains Mono", ui-monospace, monospace',
  rSheet: 30,
  rCard: 20,
  rBtn: 16,
  rRow: 16,
  scheme: 'dark',
}

const trayLight: Tokens = {
  bg: '#ebebef',
  surface: '#ffffff',
  surface2: '#f3f3f6',
  line: 'rgba(14,14,18,0.07)',
  text: '#0e0e12',
  text2: '#6c6c78',
  text3: '#a2a2ad',
  private: '#6b5fff',
  privateSoft: 'rgba(107,95,255,0.12)',
  privateText: '#5145e6',
  action: '#1f7bff',
  actionText: '#ffffff',
  ok: '#12a150',
  warn: '#d49a00',
  danger: '#e5484d',
  island: '#0e0e12',
  font: '"Onest", ui-sans-serif, sans-serif',
  numFont: '"Onest", ui-sans-serif, sans-serif',
  monoFont: '"JetBrains Mono", ui-monospace, monospace',
  rSheet: 36,
  rCard: 26,
  rBtn: 999,
  rRow: 20,
  scheme: 'light',
}

const trayDark: Tokens = {
  ...trayLight,
  bg: '#000000',
  surface: '#161618',
  surface2: '#202023',
  line: 'rgba(255,255,255,0.07)',
  text: '#f4f4f6',
  text2: '#9a9aa5',
  text3: '#5f5f69',
  private: '#7a70ff',
  privateSoft: 'rgba(122,112,255,0.18)',
  privateText: '#c4bfff',
  action: '#3898ff',
  ok: '#4bd166',
  warn: '#ffd641',
  danger: '#ff6257',
  island: '#000000',
  scheme: 'dark',
}

const ledger: Tokens = {
  bg: '#08090a',
  surface: '#0f1012',
  surface2: '#16181b',
  line: '#1e2024',
  text: '#e8e8ea',
  text2: '#8e9099',
  text3: '#5a5c64',
  private: '#7a70ff',
  privateSoft: 'rgba(122,112,255,0.14)',
  privateText: '#b9b3ff',
  action: '#3898ff',
  actionText: '#ffffff',
  ok: '#4bd166',
  warn: '#ffd641',
  danger: '#ff6257',
  island: '#000000',
  font: '"IBM Plex Sans", ui-sans-serif, sans-serif',
  numFont: '"IBM Plex Mono", ui-monospace, monospace',
  monoFont: '"IBM Plex Mono", ui-monospace, monospace',
  rSheet: 14,
  rCard: 10,
  rBtn: 8,
  rRow: 8,
  scheme: 'dark',
}

export const DIRECTIONS: Direction[] = [
  {
    id: 'veil',
    letter: 'A',
    name: 'Veil',
    concept:
      'Private by default. Your private balance is the home screen; public funds show up as a flagged strip with one tap to make them private. Sheets grow and shrink to their content, and a proof runs in a pill you can leave running.',
    lineage:
      'Zashi (private-first), Penumbra Prax (proof status), Family (content-height sheets), RainbowKit colour roles',
    tokens: veil,
  },
  {
    id: 'tray',
    letter: 'B',
    name: 'Tray',
    concept:
      'Family-style trays: every step floats over the app, sized to what it holds, with huge friendly numerals and a keypad-first send. Light by default for web and phones, with a matching dark set for Basecamp.',
    lineage:
      'Family tray system and keypad, ConnectKit step transitions, Porto dialog, RainbowKit colour roles',
    tokens: trayLight,
    dark: trayDark,
  },
  {
    id: 'ledger',
    letter: 'C',
    name: 'Ledger',
    concept:
      'An instrument for people who read what they sign: simulation first, mono numerals, public and private side by side, and proof telemetry you can inspect. Dense and exact.',
    lineage:
      'Rabby (simulation and inline blocking reasons), Penumbra (proof phases), Zerion (numerals), RainbowKit midnight',
    tokens: ledger,
  },
]

export function cssVars(t: Tokens): Record<string, string> {
  return {
    '--bg': t.bg,
    '--surface': t.surface,
    '--surface2': t.surface2,
    '--line': t.line,
    '--text': t.text,
    '--text2': t.text2,
    '--text3': t.text3,
    '--private': t.private,
    '--private-soft': t.privateSoft,
    '--private-text': t.privateText,
    '--action': t.action,
    '--action-text': t.actionText,
    '--ok': t.ok,
    '--warn': t.warn,
    '--danger': t.danger,
    '--island': t.island,
    '--font': t.font,
    '--num': t.numFont,
    '--mono': t.monoFont,
    '--r-sheet': `${t.rSheet}px`,
    '--r-card': `${t.rCard}px`,
    '--r-btn': `${t.rBtn}px`,
    '--r-row': `${t.rRow}px`,
    colorScheme: t.scheme,
  }
}
