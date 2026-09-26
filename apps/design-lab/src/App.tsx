import { motion } from 'motion/react'
import { DEMO_SPEEDUP, REAL_PROOF_SECONDS } from './lab/data'
import { usePicks } from './lab/picks'
import { DIRECTIONS } from './lab/tokens'
import { Wallet } from './lab/Wallet'

const QUESTIONS = [
  { id: 'overall', label: 'Overall direction' },
  { id: 'home', label: 'Home screen' },
  { id: 'send', label: 'Send and review' },
  { id: 'proving', label: 'Private proof (sheet and island)' },
  { id: 'connect', label: 'Connect request' },
]

function PickRow({
  id,
  label,
  value,
  note,
  saved,
  onPick,
  onNote,
}: {
  id: string
  label: string
  value?: string | null
  note?: string
  saved?: string
  onPick: (v: string) => void
  onNote: (t: string) => void
}) {
  return (
    <div
      className="grid items-center gap-3 border-t py-3 sm:grid-cols-[220px_auto_1fr_80px]"
      style={{ borderColor: 'var(--page-line)' }}
    >
      <span className="text-[14px] font-medium">{label}</span>
      <fieldset
        className="m-0 inline-flex w-fit gap-0.5 rounded-xl border-0 p-[3px]"
        style={{ background: 'var(--page-panel)', boxShadow: 'inset 0 0 0 1px var(--page-line)' }}
        aria-label={label}
      >
        {DIRECTIONS.map((d) => (
          <button
            key={d.id}
            type="button"
            aria-pressed={value === d.id}
            onClick={() => onPick(d.id)}
            className="rounded-[9px] px-3.5 py-1.5 text-[13px] font-semibold transition-colors"
            style={{
              background: value === d.id ? 'var(--page-pick)' : 'transparent',
              color: value === d.id ? '#fff' : 'var(--page-muted)',
            }}
          >
            {d.letter} · {d.name}
          </button>
        ))}
      </fieldset>
      <input
        id={`note-${id}`}
        value={note ?? ''}
        onChange={(e) => onNote(e.target.value)}
        placeholder="What would you change?"
        className="min-w-0 rounded-xl px-3 py-2 text-[14px] outline-none"
        style={{
          background: 'var(--page-panel)',
          boxShadow: 'inset 0 0 0 1px var(--page-line)',
          color: 'var(--page-text)',
        }}
      />
      <span
        className="text-[12px]"
        style={{ color: 'var(--page-faint)', fontFamily: '"JetBrains Mono", monospace' }}
      >
        {saved ?? ''}
      </span>
    </div>
  )
}

export function App() {
  const { picks, store, saved, choose, note } = usePicks()
  return (
    <div className="mx-auto max-w-[1280px] px-4 pb-24 sm:px-6">
      <header className="grid gap-4 border-b py-10" style={{ borderColor: 'var(--page-line)' }}>
        <span
          className="text-[12px] uppercase tracking-[0.1em]"
          style={{ color: 'var(--page-muted)', fontFamily: '"JetBrains Mono", monospace' }}
        >
          Logos Kit · wallet design · v2
        </span>
        <h1
          className="max-w-[20ch] text-[clamp(32px,5vw,52px)] font-semibold leading-[1.02] tracking-[-0.03em]"
          style={{ textWrap: 'balance' }}
        >
          Three wallets. Tap through all of them.
        </h1>
        <p
          className="max-w-[70ch] text-[16px] leading-relaxed"
          style={{ color: 'var(--page-muted)' }}
        >
          Each phone below is a working prototype, not a picture. Press{' '}
          <b className="text-[var(--page-text)]">Send</b> to go through amount, review and a
          real-length private proof, then close the sheet and watch the proof keep running in the
          island. Press the chip at the bottom to see an app ask to connect. The three differ in
          concept, not just colour. Built from author components (21st.dev, Motion Primitives,
          NumberFlow, Vaul) on RainbowKit colour roles.
        </p>
        <p className="text-[13px]" style={{ color: 'var(--page-faint)' }}>
          Proof timing is measured, not guessed: a private proof took {REAL_PROOF_SECONDS} s (
          {(REAL_PROOF_SECONDS / 60).toFixed(1)} min) on an Apple Silicon Mac. The demo plays it{' '}
          {DEMO_SPEEDUP}× faster; the countdown shows real time.
        </p>
      </header>

      <section className="-mx-4 overflow-x-auto px-4 py-10 sm:-mx-6 sm:px-6">
        <div className="flex min-w-min gap-8">
          {DIRECTIONS.map((d, i) => (
            <motion.article
              key={d.id}
              initial={{ opacity: 1, y: 0 }}
              className="grid w-[380px] shrink-0 content-start gap-4"
            >
              <div className="grid gap-2">
                <div className="flex items-center gap-2.5">
                  <span
                    className="grid size-7 place-items-center rounded-lg text-[13px] font-semibold"
                    style={{
                      background: 'var(--page-panel)',
                      boxShadow: 'inset 0 0 0 1px var(--page-line)',
                      fontFamily: '"JetBrains Mono", monospace',
                    }}
                  >
                    {d.letter}
                  </span>
                  <h2 className="text-[20px] font-semibold tracking-[-0.01em]">{d.name}</h2>
                  {i === 0 && (
                    <span
                      className="rounded-full px-2 py-0.5 text-[11px] font-semibold"
                      style={{
                        color: '#bcdcff',
                        background: 'rgba(56,152,255,0.14)',
                        boxShadow: 'inset 0 0 0 1px rgba(56,152,255,0.35)',
                      }}
                    >
                      Recommended
                    </span>
                  )}
                </div>
                <p className="text-[14px] leading-relaxed" style={{ color: 'var(--page-muted)' }}>
                  {d.concept}
                </p>
                <p className="text-[12px]" style={{ color: 'var(--page-faint)' }}>
                  From: {d.lineage}
                </p>
              </div>
              <Wallet d={d} />
            </motion.article>
          ))}
        </div>
      </section>

      <section className="grid gap-2 pt-2">
        <h2 className="text-[22px] font-semibold tracking-[-0.01em]">Your picks</h2>
        <p className="text-[14px]" style={{ color: 'var(--page-muted)' }}>
          Mix freely: pick a direction per part and say what to change.{' '}
          {store === 'page'
            ? 'Picks save to this page and Claude reads them.'
            : store === 'local'
              ? 'Picks save in this browser only here; tell Claude in chat.'
              : 'Connecting…'}
        </p>
        <div className="mt-2">
          {QUESTIONS.map((q) => (
            <PickRow
              key={q.id}
              id={q.id}
              label={q.label}
              value={picks[q.id]?.option}
              note={picks[q.id]?.note}
              saved={saved[q.id]}
              onPick={(v) => choose(q.id, v)}
              onNote={(t) => note(q.id, t)}
            />
          ))}
        </div>
      </section>

      <section className="mt-12 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        {[
          [
            'Same design in Basecamp',
            'The picked direction becomes one token set that feeds QML (Tokens.qml), React and React Native. Sheets, springs and the island map to QML Behaviors, MultiEffect and Shape.',
          ],
          [
            'Private has its own colour',
            'Purple only ever means private (RainbowKit #7A70FF). Blue is for public and neutral actions (#3898FF). Nothing else borrows them.',
          ],
          [
            'Honest numbers',
            'Balances never show a fake 0 while syncing, locked funds are called out during a proof, and the fee is a ceiling (≤) until it is known.',
          ],
          [
            'Checked against the sandbox',
            'Basecamp blocks remote images, so the Logos mark and token logos ship inside the module. Identicons are Rectangle grids; Canvas also paints (tested).',
          ],
        ].map(([t, b]) => (
          <div
            key={t}
            className="rounded-2xl p-4"
            style={{
              background: 'var(--page-panel)',
              boxShadow: 'inset 0 0 0 1px var(--page-line)',
            }}
          >
            <b className="mb-1 block text-[14px] font-semibold">{t}</b>
            <span className="text-[13px] leading-relaxed" style={{ color: 'var(--page-muted)' }}>
              {b}
            </span>
          </div>
        ))}
      </section>
    </div>
  )
}
