// Demo content. Amounts are LEZ testnet units; addresses are shortened real-format base58.

export type Account = {
  id: string
  label: string
  kind: 'public' | 'private'
  short: string
  seed: string
  balance: number
}

export const ACCOUNTS: Account[] = [
  {
    id: 'p1',
    label: 'Private account 1',
    kind: 'private',
    short: 'ends K7-QX',
    seed: 'private-1',
    balance: 35.7,
  },
  {
    id: 'a1',
    label: 'Public account 1',
    kind: 'public',
    short: '7Hk3…W9Qp',
    seed: '7Hk3xQvN2cRt5mYbJp8LsWd4FgUe6nKaZq1mR8aW9Qp',
    balance: 42.5,
  },
  {
    id: 'a2',
    label: 'Public account 2',
    kind: 'public',
    short: 'Bm2v…PL4a',
    seed: 'Bm2vC9sDj4YkQ7eHw3NpXt6RuLf8GzAb5VcKq2PpL4a',
    balance: 3,
  },
]

export const DAPP = {
  name: 'Testimonials',
  module: 'logos_kit_testimonial',
  version: '0.3.1',
  monogram: 'TE',
}

export const RECIPIENT = { label: 'ends 4Q-MN', note: 'Private receive code' }

/** Measured on this machine (S0 benchmark E2, public+private circuit): 337 s. */
export const REAL_PROOF_SECONDS = 337
/** The demo plays the same phases 15x faster so the whole flow fits in a review. */
export const DEMO_SPEEDUP = 15
