import NumberFlow from '@number-flow/react'
import {
  ArrowDown,
  ArrowUp,
  Check,
  ChevronDown,
  Delete,
  Droplet,
  Eye,
  EyeOff,
  Info,
  Lock,
  Moon,
  Shield,
  Sun,
} from 'lucide-react'
import { AnimatePresence, motion } from 'motion/react'
import { type ReactNode, useEffect, useMemo, useState } from 'react'
import AnimatedBackground from '@/components/ui/animated-tabs'
import { BorderTrail } from '@/components/ui/border-trail'
import {
  CircularProgress,
  CircularProgressIndicator,
  CircularProgressRange,
  CircularProgressTrack,
} from '@/components/ui/circular-progress'
import { DynamicIsland } from '@/components/ui/dynamic-island'
import { TextShimmer } from '@/components/ui/text-shimmer'
import { AppMonogram, fmt, Identicon, LezToken, LogosMark } from './atoms'
import { ACCOUNTS, DAPP, REAL_PROOF_SECONDS, RECIPIENT } from './data'
import { formatLeft, PHASE_LABEL, type ProofState, useProof } from './proof'
import { Sheet } from './Sheet'
import { cssVars, type Direction, type Tokens } from './tokens'

type Flow =
  | { flow: 'send'; step: 'amount' | 'review' | 'proving'; dir: 1 | -1 }
  | { flow: 'connect'; step: 'request' | 'accounts' | 'done'; dir: 1 | -1 }

type Activity = {
  id: string
  title: string
  sub: string
  tag?: 'ok' | 'pending' | 'unconfirmed'
  kind: 'in' | 'out' | 'faucet' | 'private'
}

const SEGMENT_IDS = Array.from({ length: 61 }, (_, i) => `seg-${i}`)

const START_ACTIVITY: Activity[] = [
  {
    id: 'r1',
    title: 'Received 20.00 LEZ',
    sub: 'Private · yesterday · block 25,611',
    tag: 'ok',
    kind: 'in',
  },
  {
    id: 'r2',
    title: 'Made private 15.70 LEZ',
    sub: 'From Public account 1 · Mon',
    tag: 'ok',
    kind: 'private',
  },
  {
    id: 'r3',
    title: 'Test funds',
    sub: 'Faucet → Public account 1 · Mon',
    tag: 'ok',
    kind: 'faucet',
  },
]

/* ---------- small building blocks ---------- */

function Num({
  value,
  size,
  dim = true,
  className = '',
}: {
  value: number
  size: number
  dim?: boolean
  className?: string
}) {
  // Whole part at full weight, cents lighter (Zerion/Uniswap).
  return (
    <span
      className={`inline-flex items-baseline tabular-nums ${className}`}
      style={{ fontFamily: 'var(--num)', fontSize: size, lineHeight: 1 }}
    >
      <NumberFlow
        value={value}
        format={{ minimumFractionDigits: 2, maximumFractionDigits: 2 }}
        style={{ ['--number-flow-char-height' as string]: '0.9em' }}
      />
      <span
        style={{
          fontSize: size * 0.42,
          marginLeft: size * 0.12,
          color: dim ? 'var(--text2)' : 'inherit',
          fontWeight: 500,
        }}
      >
        LEZ
      </span>
    </span>
  )
}

function Btn({
  children,
  onClick,
  tone = 'neutral',
  disabled,
  full,
  size = 'md',
}: {
  children: ReactNode
  onClick?: () => void
  tone?: 'private' | 'action' | 'neutral' | 'ink' | 'ghost'
  disabled?: boolean
  full?: boolean
  size?: 'md' | 'lg'
}) {
  const bg = {
    private: 'var(--private)',
    action: 'var(--action)',
    neutral: 'var(--surface2)',
    ink: 'var(--text)',
    ghost: 'transparent',
  }[tone]
  const fg = {
    private: '#fff',
    action: 'var(--action-text)',
    neutral: 'var(--text)',
    ink: 'var(--bg)',
    ghost: 'var(--text2)',
  }[tone]
  return (
    <motion.button
      type="button"
      whileHover={disabled ? undefined : { scale: 1.02 }}
      whileTap={disabled ? undefined : { scale: 0.96 }}
      transition={{ type: 'spring', stiffness: 500, damping: 30 }}
      onClick={onClick}
      disabled={disabled}
      className={`inline-flex items-center justify-center gap-2 whitespace-nowrap font-semibold transition-opacity [&_svg]:shrink-0 disabled:cursor-not-allowed disabled:opacity-40 ${full ? 'w-full' : ''}`}
      style={{
        background: bg,
        color: fg,
        borderRadius: 'var(--r-btn)',
        padding: size === 'lg' ? '15px 20px' : '11px 16px',
        fontSize: size === 'lg' ? 16 : 14,
        border: tone === 'ghost' ? '1px solid var(--line)' : 0,
      }}
    >
      {children}
    </motion.button>
  )
}

function Pill({ children }: { children: ReactNode }) {
  return (
    <span
      className="inline-flex items-center gap-1.5 whitespace-nowrap py-1 pl-1 pr-2.5 text-[13px] font-semibold"
      style={{ background: 'var(--surface2)', borderRadius: 999 }}
    >
      {children}
    </span>
  )
}

function Network() {
  return (
    <Pill>
      <span className="grid size-5 place-items-center rounded-full bg-black">
        <LogosMark size={11} />
      </span>
      <span className="size-1.5 rounded-full" style={{ background: 'var(--ok)' }} />
      LEZ testnet
    </Pill>
  )
}

function Tag({
  tone,
  children,
}: {
  tone: 'ok' | 'pending' | 'unconfirmed' | 'private'
  children: ReactNode
}) {
  const map = {
    ok: ['var(--ok)', 'color-mix(in srgb, var(--ok) 14%, transparent)'],
    pending: ['var(--text2)', 'var(--surface2)'],
    unconfirmed: ['var(--warn)', 'color-mix(in srgb, var(--warn) 14%, transparent)'],
    private: ['var(--private-text)', 'var(--private-soft)'],
  }[tone]
  return (
    <span
      className="inline-flex items-center gap-1 whitespace-nowrap rounded-full px-2 py-0.5 text-[11px] font-semibold"
      style={{ color: map[0], background: map[1] }}
    >
      {children}
    </span>
  )
}

function ActivityIcon({ kind }: { kind: Activity['kind'] }) {
  const priv = kind === 'private' || kind === 'out'
  return (
    <span
      className="grid size-9 shrink-0 place-items-center"
      style={{
        borderRadius: 'calc(var(--r-row) * 0.8)',
        background: priv ? 'var(--private-soft)' : 'var(--surface2)',
        color: priv ? 'var(--private-text)' : 'var(--text2)',
      }}
    >
      {kind === 'in' ? (
        <ArrowDown size={16} />
      ) : kind === 'faucet' ? (
        <Droplet size={16} />
      ) : kind === 'out' ? (
        <ArrowUp size={16} />
      ) : (
        <Shield size={16} />
      )}
    </span>
  )
}

function ProofRow({ proof, onOpen }: { proof: ProofState; onOpen: () => void }) {
  return (
    <button
      type="button"
      onClick={onOpen}
      className="flex w-full items-center gap-3 py-2.5 text-left"
    >
      <span
        className="grid size-9 shrink-0 place-items-center"
        style={{
          borderRadius: 'calc(var(--r-row) * 0.8)',
          background: 'var(--private-soft)',
          color: 'var(--private-text)',
        }}
      >
        <Lock size={15} />
      </span>
      <span className="min-w-0 flex-1">
        <span className="block text-[14px] font-semibold">Sending 12.50 LEZ privately</span>
        <TextShimmer
          className="text-[12px] [--base-color:var(--text2)] [--base-gradient-color:var(--text)]"
          duration={1.6}
        >
          {`${PHASE_LABEL[proof.phase]} · ${formatLeft(proof.realLeft)}`}
        </TextShimmer>
        <span
          className="mt-1.5 block h-[3px] overflow-hidden rounded-full"
          style={{ background: 'var(--surface2)' }}
        >
          <motion.span
            className="block h-full rounded-full"
            style={{ background: 'var(--private)' }}
            animate={{ width: `${Math.round(proof.pct * 100)}%` }}
            transition={{ ease: 'linear', duration: 0.1 }}
          />
        </span>
      </span>
    </button>
  )
}

function ActivityList({
  items,
  proof,
  onOpenProof,
}: {
  items: Activity[]
  proof: ProofState | null
  onOpenProof: () => void
}) {
  return (
    <div className="flex flex-col">
      <AnimatePresence initial={false}>
        {proof && proof.phase !== 'done' && (
          <motion.div
            key="proof"
            layout
            initial={{ opacity: 0, y: -8 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, height: 0 }}
          >
            <ProofRow proof={proof} onOpen={onOpenProof} />
          </motion.div>
        )}
        {items.map((a) => (
          <motion.div
            key={a.id}
            layout
            initial={{ opacity: 0, y: -8 }}
            animate={{ opacity: 1, y: 0 }}
            className="flex items-center gap-3 py-2.5"
          >
            <ActivityIcon kind={a.kind} />
            <span className="min-w-0 flex-1">
              <span className="block truncate text-[14px] font-semibold">{a.title}</span>
              <span className="block truncate text-[12px]" style={{ color: 'var(--text2)' }}>
                {a.sub}
              </span>
            </span>
            {a.tag === 'ok' && <Tag tone="ok">Confirmed</Tag>}
            {a.tag === 'unconfirmed' && <Tag tone="unconfirmed">Not confirmed yet</Tag>}
          </motion.div>
        ))}
      </AnimatePresence>
    </div>
  )
}

/* ---------- the wallet ---------- */

export function Wallet({ d }: { d: Direction }) {
  const [darkTray, setDarkTray] = useState(false)
  const tokens: Tokens = d.id === 'tray' && darkTray && d.dark ? d.dark : d.tokens
  const [priv, setPriv] = useState(35.7)
  const [pub] = useState(42.5)
  const [hidden, setHidden] = useState(false)
  const [activity, setActivity] = useState(START_ACTIVITY)
  const [sheet, setSheet] = useState<Flow | null>(null)
  const [amount, setAmount] = useState('12.5')
  const [connected, setConnected] = useState(false)
  const [island, setIsland] = useState<'idle' | 'timer' | 'ring' | null>(null)
  const [tab, setTab] = useState<'private' | 'public'>('private')

  const { proof, start, reset } = useProof(() => {
    setActivity((a) => [
      {
        id: `s${Date.now()}`,
        title: 'Sent 12.50 LEZ privately',
        sub: `To ${RECIPIENT.label} · just now`,
        tag: 'ok',
        kind: 'out',
      },
      ...a,
    ])
    setIsland('ring')
    window.setTimeout(() => {
      setIsland(null)
      reset()
    }, 3200)
  })

  const proving = proof !== null && proof.phase !== 'done'
  useEffect(() => {
    if (proving && sheet?.step !== 'proving') setIsland('timer')
    if (sheet && sheet.step === 'proving') setIsland((v) => (v === 'ring' ? v : null))
  }, [proving, sheet])

  const value = Number.parseFloat(amount || '0') || 0
  // Position + character is each typed digit's identity, so a new digit animates in.
  const amountChars = (amount || '0').split('').map((c, i) => ({ c, id: `${i}:${c}` }))
  const spendable = priv
  const tooMuch = value > spendable

  const open = (f: Flow) => setSheet(f)
  const go = (step: string, dir: 1 | -1 = 1) =>
    setSheet((s) => (s ? ({ ...s, step, dir } as Flow) : s))
  const close = () => setSheet(null)

  const startSend = () => {
    setPriv((p) => p - value)
    start()
    go('proving')
  }

  const key = (k: string) => {
    setAmount((a) => {
      if (k === 'del') return a.slice(0, -1)
      if (k === '.') return a.includes('.') ? a : `${a || '0'}.`
      if (a.includes('.') && a.split('.')[1].length >= 2) return a
      if (a === '0') return k
      return (a + k).slice(0, 9)
    })
  }

  const vars = useMemo(() => cssVars(tokens), [tokens])
  const kind = d.id

  /* ----- homes ----- */
  const top = (
    <div className="flex items-center justify-between">
      <Pill>
        <Identicon seed="private-1" size={24} square={kind === 'ledger'} />
        Private account 1
        <ChevronDown size={14} style={{ color: 'var(--text3)' }} />
      </Pill>
      <div className="flex items-center gap-2">
        {kind === 'tray' && (
          <button
            type="button"
            aria-label="Toggle dark"
            onClick={() => setDarkTray((v) => !v)}
            className="grid size-8 place-items-center rounded-full"
            style={{ background: 'var(--surface2)', color: 'var(--text2)' }}
          >
            {darkTray ? <Sun size={15} /> : <Moon size={15} />}
          </button>
        )}
        <Network />
      </div>
    </div>
  )

  const actions = (
    <div className="grid grid-cols-3 gap-2">
      <Btn
        tone={kind === 'tray' ? 'ink' : 'private'}
        onClick={() => open({ flow: 'send', step: 'amount', dir: 1 })}
        full
      >
        <ArrowUp size={16} /> Send
      </Btn>
      <Btn full>
        <ArrowDown size={16} /> Receive
      </Btn>
      <Btn full>
        <Droplet size={16} /> {kind === 'ledger' ? 'Faucet' : 'Add'}
      </Btn>
    </div>
  )

  const veilHome = (
    <div className="flex flex-col gap-5">
      {top}
      <div className="flex flex-col items-center gap-2 pt-4 text-center">
        <span
          className="inline-flex items-center gap-1.5 text-[13px] font-semibold"
          style={{ color: 'var(--private-text)' }}
        >
          <Shield size={14} /> Private balance
          <button
            type="button"
            aria-label={hidden ? 'Show balance' : 'Hide balance'}
            onClick={() => setHidden((h) => !h)}
            style={{ color: 'var(--text3)' }}
          >
            {hidden ? <EyeOff size={14} /> : <Eye size={14} />}
          </button>
        </span>
        {hidden ? (
          <span
            className="text-[52px] font-semibold tracking-tight"
            style={{ color: 'var(--text3)' }}
          >
            ••••
          </span>
        ) : (
          <span className="font-semibold tracking-tight">
            <Num value={priv} size={52} />
          </span>
        )}
        <span className="text-[13px]" style={{ color: 'var(--text2)' }}>
          {proving
            ? `${fmt(12.5)} LEZ locked until the proof finishes`
            : 'Only you can see this. Not even the network.'}
        </span>
      </div>
      {actions}
      <div
        className="flex items-center gap-3 px-3.5 py-3"
        style={{
          background: 'var(--surface)',
          borderRadius: 'var(--r-card)',
          boxShadow: 'inset 0 0 0 1px var(--line)',
        }}
      >
        <Identicon seed={ACCOUNTS[1].seed} size={30} />
        <span className="min-w-0 flex-1">
          <span className="block text-[13px] font-semibold">{fmt(pub)} LEZ public</span>
          <span className="block text-[12px]" style={{ color: 'var(--text2)' }}>
            Visible to everyone on Public account 1
          </span>
        </span>
        <button
          type="button"
          className="whitespace-nowrap rounded-full px-3 py-1.5 text-[12px] font-semibold"
          style={{ color: 'var(--private-text)', background: 'var(--private-soft)' }}
        >
          Make private
        </button>
      </div>
      <div>
        <div
          className="mb-1 text-[12px] font-semibold uppercase tracking-[0.06em]"
          style={{ color: 'var(--text3)' }}
        >
          Activity
        </div>
        <ActivityList
          items={activity}
          proof={proof}
          onOpenProof={() => open({ flow: 'send', step: 'proving', dir: 1 })}
        />
      </div>
    </div>
  )

  const trayHome = (
    <div className="flex flex-col gap-3">
      {top}
      <div
        className="flex flex-col gap-4 p-5"
        style={{
          background: 'var(--surface)',
          borderRadius: 'var(--r-card)',
          boxShadow:
            tokens.scheme === 'light'
              ? '0 1px 2px rgba(0,0,0,0.04), 0 8px 24px rgba(0,0,0,0.05)'
              : 'none',
        }}
      >
        <div className="flex items-center justify-between">
          <span className="text-[13px] font-semibold" style={{ color: 'var(--text2)' }}>
            Private balance
          </span>
          <Tag tone="private">
            <Shield size={11} /> Only you
          </Tag>
        </div>
        <span className="font-bold tracking-[-0.03em]">
          <Num value={priv} size={58} />
        </span>
        {actions}
      </div>
      <div className="-mx-1 flex gap-2 overflow-x-auto p-1">
        {ACCOUNTS.map((a) => (
          <div
            key={a.id}
            className="flex shrink-0 items-center gap-2 py-2 pl-2 pr-3.5"
            style={{
              background: 'var(--surface)',
              borderRadius: 999,
              boxShadow: a.id === 'p1' ? '0 0 0 2px var(--text)' : 'none',
            }}
          >
            <Identicon seed={a.seed} size={26} />
            <span className="text-[12px] leading-tight">
              <b className="block font-semibold">
                {a.kind === 'private' ? 'Private 1' : a.label.replace('Public account', 'Public')}
              </b>
              <span style={{ color: 'var(--text2)' }}>
                {fmt(a.kind === 'private' ? priv : a.id === 'a1' ? pub : a.balance)}
              </span>
            </span>
          </div>
        ))}
      </div>
      <div className="p-4" style={{ background: 'var(--surface)', borderRadius: 'var(--r-card)' }}>
        <div className="mb-1 text-[13px] font-semibold" style={{ color: 'var(--text2)' }}>
          Recent
        </div>
        <ActivityList
          items={activity}
          proof={proof}
          onOpenProof={() => open({ flow: 'send', step: 'proving', dir: 1 })}
        />
      </div>
    </div>
  )

  const ledgerHome = (
    <div className="flex flex-col gap-4">
      <div className="flex items-center justify-between">
        <span className="inline-flex items-center gap-2 text-[13px] font-semibold">
          <span className="grid size-6 place-items-center rounded-md bg-black">
            <LogosMark size={13} />
          </span>
          Logos Kit
        </span>
        <span
          className="font-mono text-[11px]"
          style={{ color: 'var(--text2)', fontFamily: 'var(--mono)' }}
        >
          <span
            className="mr-1.5 inline-block size-1.5 rounded-full align-middle"
            style={{ background: 'var(--ok)' }}
          />
          lez:testnet · #25,947
        </span>
      </div>
      <div
        className="flex p-1"
        style={{
          background: 'var(--surface)',
          borderRadius: 'var(--r-card)',
          boxShadow: 'inset 0 0 0 1px var(--line)',
        }}
      >
        <AnimatedBackground
          defaultValue={tab}
          onValueChange={(v) => v && setTab(v as 'private' | 'public')}
          className="rounded-md"
          transition={{ type: 'spring', bounce: 0.2, duration: 0.3 }}
        >
          {(['private', 'public'] as const).map((t) => (
            <button
              key={t}
              data-id={t}
              type="button"
              className="flex-1 justify-center py-1.5 text-[13px] font-semibold capitalize"
              style={{ color: tab === t ? 'var(--text)' : 'var(--text2)' }}
            >
              <span className="relative z-10 inline-flex items-center gap-1.5">
                {t === 'private' ? (
                  <Shield size={13} style={{ color: 'var(--private)' }} />
                ) : (
                  <Eye size={13} />
                )}
                {t}
              </span>
            </button>
          ))}
        </AnimatedBackground>
      </div>
      <style>{'[data-id][aria-selected="true"] > div.absolute{background:var(--surface2)}'}</style>
      {tab === 'private' ? (
        <div className="grid gap-3">
          <div className="flex items-end justify-between">
            <span className="text-[12px]" style={{ color: 'var(--text2)' }}>
              Private account 1 · ends K7-QX
            </span>
            <span className="font-medium">
              <Num value={priv} size={30} />
            </span>
          </div>
          <div
            className="grid grid-cols-3 overflow-hidden text-[12px]"
            style={{ borderRadius: 'var(--r-card)', boxShadow: 'inset 0 0 0 1px var(--line)' }}
          >
            {[
              ['Spendable', proving ? priv : priv, 'var(--private)'],
              ['Pending', 0, 'var(--text2)'],
              ['In a proof', proving ? 12.5 : 0, 'var(--warn)'],
            ].map(([label, v, c], i) => (
              <div
                key={label as string}
                className="grid gap-1 p-2.5"
                style={{ borderLeft: i ? '1px solid var(--line)' : 0 }}
              >
                <span
                  className="inline-flex items-center gap-1.5"
                  style={{ color: 'var(--text2)' }}
                >
                  <i className="size-1.5 rounded-sm" style={{ background: c as string }} />
                  {label as string}
                </span>
                <span className="tabular-nums" style={{ fontFamily: 'var(--mono)', fontSize: 13 }}>
                  {fmt(v as number)}
                </span>
              </div>
            ))}
          </div>
        </div>
      ) : (
        <div
          className="grid"
          style={{ borderRadius: 'var(--r-card)', boxShadow: 'inset 0 0 0 1px var(--line)' }}
        >
          {ACCOUNTS.filter((a) => a.kind === 'public').map((a, i) => (
            <div
              key={a.id}
              className="flex items-center gap-3 px-3 py-2.5"
              style={{ borderTop: i ? '1px solid var(--line)' : 0 }}
            >
              <Identicon seed={a.seed} size={26} square />
              <span className="min-w-0 flex-1 text-[13px]">
                <b className="block font-semibold">{a.label}</b>
                <span style={{ color: 'var(--text2)', fontFamily: 'var(--mono)', fontSize: 11 }}>
                  {a.short}
                </span>
              </span>
              <span className="tabular-nums" style={{ fontFamily: 'var(--mono)', fontSize: 13 }}>
                {fmt(a.id === 'a1' ? pub : a.balance)}
              </span>
            </div>
          ))}
        </div>
      )}
      {actions}
      <div>
        <div
          className="mb-1 text-[11px] uppercase tracking-[0.08em]"
          style={{ color: 'var(--text3)', fontFamily: 'var(--mono)' }}
        >
          Activity
        </div>
        <ActivityList
          items={activity}
          proof={proof}
          onOpenProof={() => open({ flow: 'send', step: 'proving', dir: 1 })}
        />
      </div>
    </div>
  )

  /* ----- sheets ----- */
  const Title = ({ children, sub }: { children: ReactNode; sub?: ReactNode }) => (
    <div className="mb-4 flex flex-col gap-1">
      <h3 className="text-[20px] font-semibold tracking-[-0.01em]" style={{ textWrap: 'balance' }}>
        {children}
      </h3>
      {sub && (
        <span className="text-[13px]" style={{ color: 'var(--text2)' }}>
          {sub}
        </span>
      )}
    </div>
  )

  const Row = ({ label, children }: { label: string; children: ReactNode }) => (
    <div
      className="flex items-center justify-between gap-4 py-2.5 text-[13px]"
      style={{ borderTop: '1px solid var(--line)' }}
    >
      <span style={{ color: 'var(--text2)' }}>{label}</span>
      <span className="min-w-0 text-right font-semibold">{children}</span>
    </div>
  )

  let sheetBody: ReactNode = null
  if (sheet?.flow === 'send' && sheet.step === 'amount') {
    sheetBody = (
      <div>
        <Title sub={<>From Private account 1 · {fmt(spendable)} LEZ spendable</>}>
          Send privately
        </Title>
        <div
          className="mb-3 flex items-center gap-2 px-3 py-2 text-[13px]"
          style={{ background: 'var(--surface2)', borderRadius: 'var(--r-row)' }}
        >
          <span style={{ color: 'var(--text2)' }}>To</span>
          <b className="font-semibold">{RECIPIENT.label}</b>
          <span className="ml-auto text-[12px]" style={{ color: 'var(--text3)' }}>
            {RECIPIENT.note}
          </span>
        </div>
        <div
          className="flex items-baseline justify-center gap-1 py-5 font-semibold tabular-nums"
          style={{ fontFamily: 'var(--num)', fontSize: 50, letterSpacing: '-0.03em' }}
        >
          <AnimatePresence initial={false} mode="popLayout">
            {amountChars.map(({ c, id }) => (
              <motion.span
                key={id}
                layout
                initial={{ opacity: 0, y: 12, scale: 0.8 }}
                animate={{ opacity: 1, y: 0, scale: 1 }}
                exit={{ opacity: 0, y: -12, scale: 0.8 }}
                transition={{ type: 'spring', stiffness: 520, damping: 32 }}
              >
                {c}
              </motion.span>
            ))}
          </AnimatePresence>
          <span className="ml-1 text-[20px]" style={{ color: 'var(--text2)' }}>
            LEZ
          </span>
        </div>
        <div className="mb-3 grid grid-cols-3 gap-1">
          {['1', '2', '3', '4', '5', '6', '7', '8', '9', '.', '0', 'del'].map((k) => (
            <motion.button
              key={k}
              type="button"
              whileTap={{ scale: 0.9 }}
              onClick={() => key(k)}
              className="grid h-11 place-items-center text-[20px] font-medium"
              style={{ borderRadius: 'var(--r-row)', color: 'var(--text)' }}
              aria-label={k === 'del' ? 'Delete' : k}
            >
              {k === 'del' ? <Delete size={20} /> : k}
            </motion.button>
          ))}
        </div>
        <Btn
          tone={kind === 'tray' ? 'ink' : 'private'}
          size="lg"
          full
          disabled={value <= 0 || tooMuch}
          onClick={() => go('review')}
        >
          Review
        </Btn>
        <AnimatePresence>
          {tooMuch && (
            <motion.p
              initial={{ opacity: 0, height: 0 }}
              animate={{ opacity: 1, height: 'auto' }}
              exit={{ opacity: 0, height: 0 }}
              className="pt-2 text-center text-[12px]"
              style={{ color: 'var(--danger)' }}
            >
              You have {fmt(spendable)} LEZ spendable. Lower the amount or make public funds private
              first.
            </motion.p>
          )}
        </AnimatePresence>
      </div>
    )
  } else if (sheet?.flow === 'send' && sheet.step === 'review') {
    sheetBody = (
      <div>
        <Title>Review</Title>
        <div
          className="mb-3 flex items-center gap-3 p-3.5"
          style={{ background: 'var(--surface2)', borderRadius: 'var(--r-card)' }}
        >
          <LezToken size={38} />
          <span className="flex-1">
            <span className="block text-[12px]" style={{ color: 'var(--text2)' }}>
              Your private balance changes
            </span>
            <span
              className="text-[22px] font-semibold tabular-nums"
              style={{ color: 'var(--danger)', fontFamily: 'var(--num)' }}
            >
              − {fmt(value)} LEZ
            </span>
          </span>
        </div>
        <Row label="To">{RECIPIENT.label}</Row>
        <Row label="From">Private account 1</Row>
        <Row label="Visibility">
          <span className="inline-flex items-center gap-1" style={{ color: 'var(--private-text)' }}>
            <Shield size={13} /> Amount, sender and recipient stay private
          </span>
        </Row>
        <Row label="Proof">
          Runs on this device · about {Math.round(REAL_PROOF_SECONDS / 60)} min
        </Row>
        <Row label="Network fee">≤ 0.0021 LEZ</Row>
        <div className="pt-3">
          <Btn tone={kind === 'tray' ? 'ink' : 'private'} size="lg" full onClick={startSend}>
            <Lock size={16} /> Prove and send
          </Btn>
        </div>
      </div>
    )
  } else if (sheet?.flow === 'send' && sheet.step === 'proving') {
    const p = proof
    const doneNow = !p || p.phase === 'done'
    sheetBody = doneNow ? (
      <div className="flex flex-col items-center gap-3 py-6 text-center">
        <motion.span
          initial={{ scale: 0.4, opacity: 0 }}
          animate={{ scale: 1, opacity: 1 }}
          transition={{ type: 'spring', stiffness: 400, damping: 18 }}
          className="grid size-16 place-items-center rounded-full"
          style={{
            background: 'color-mix(in srgb, var(--ok) 16%, transparent)',
            color: 'var(--ok)',
          }}
        >
          <Check size={30} />
        </motion.span>
        <h3 className="text-[20px] font-semibold">Sent privately</h3>
        <span className="text-[13px]" style={{ color: 'var(--text2)' }}>
          12.50 LEZ to {RECIPIENT.label}. Only you and the recipient can see it.
        </span>
        <div className="w-full pt-2">
          <Btn full onClick={close}>
            Done
          </Btn>
        </div>
      </div>
    ) : (
      <div>
        <Title sub={<>12.50 LEZ to {RECIPIENT.label}</>}>Sending privately</Title>
        {kind === 'tray' ? (
          <div className="flex flex-col items-center gap-2 py-3">
            <CircularProgress value={Math.round(p.pct * 100)} size={148} thickness={10}>
              <CircularProgressIndicator>
                <CircularProgressTrack className="text-[var(--surface2)]" />
                <CircularProgressRange className="text-[var(--private)]" />
              </CircularProgressIndicator>
              <span className="absolute inset-0 grid place-items-center text-center">
                <span>
                  <span className="block text-[30px] font-bold tabular-nums">
                    {Math.round(p.pct * 100)}%
                  </span>
                  <span className="text-[12px]" style={{ color: 'var(--text2)' }}>
                    {formatLeft(p.realLeft)}
                  </span>
                </span>
              </span>
            </CircularProgress>
            <TextShimmer className="text-[14px] font-semibold [--base-color:var(--text2)] [--base-gradient-color:var(--text)]">
              {PHASE_LABEL[p.phase]}
            </TextShimmer>
          </div>
        ) : kind === 'ledger' ? (
          <div className="grid gap-2">
            <div
              className="grid gap-1 p-3 text-[11.5px]"
              style={{
                fontFamily: 'var(--mono)',
                background: '#000',
                borderRadius: 'var(--r-card)',
                boxShadow: 'inset 0 0 0 1px var(--line)',
                color: 'var(--text2)',
              }}
            >
              <span>
                phase <b style={{ color: 'var(--text)' }}>{p.phase}</b> · {formatLeft(p.realLeft)}
              </span>
              <span>
                segment {p.segment}/{p.segments} · keccak po2 17
              </span>
              <span style={{ color: 'var(--private-text)' }}>
                cpu prover · 10 threads · peak ~4.3 GB
              </span>
              <span className="mt-1 grid grid-cols-[repeat(61,1fr)] gap-[1px]">
                {SEGMENT_IDS.map((id, i) => (
                  <i
                    key={id}
                    className="h-2"
                    style={{ background: i < p.segment ? 'var(--private)' : 'var(--surface2)' }}
                  />
                ))}
              </span>
            </div>
          </div>
        ) : (
          <div
            className="relative overflow-hidden p-4"
            style={{ background: 'var(--surface2)', borderRadius: 'var(--r-card)' }}
          >
            <BorderTrail
              size={70}
              style={{
                background: 'linear-gradient(90deg, transparent, var(--private), transparent)',
              }}
              className="bg-transparent"
            />
            <div className="flex items-baseline justify-between">
              <TextShimmer className="text-[15px] font-semibold [--base-color:var(--private-text)] [--base-gradient-color:#fff]">
                {PHASE_LABEL[p.phase]}
              </TextShimmer>
              <span className="text-[13px] tabular-nums" style={{ color: 'var(--text2)' }}>
                {formatLeft(p.realLeft)}
              </span>
            </div>
            <div
              className="mt-3 h-2 overflow-hidden rounded-full"
              style={{ background: 'var(--bg)' }}
            >
              <motion.div
                className="h-full rounded-full"
                style={{ background: 'linear-gradient(90deg, var(--private), #a59fff)' }}
                animate={{ width: `${Math.max(2, Math.round(p.pct * 100))}%` }}
                transition={{ ease: 'linear', duration: 0.1 }}
              />
            </div>
          </div>
        )}
        <div className="mt-4 grid gap-2">
          {(['preparing', 'proving', 'submitting', 'waiting'] as const).map((ph) => {
            const order = ['preparing', 'proving', 'submitting', 'waiting', 'done']
            const state =
              order.indexOf(p.phase) > order.indexOf(ph) ? 'done' : p.phase === ph ? 'now' : 'todo'
            return (
              <div key={ph} className="flex items-center gap-2.5 text-[13px]">
                <span
                  className="grid size-5 place-items-center rounded-full"
                  style={{
                    background:
                      state === 'done'
                        ? 'color-mix(in srgb, var(--ok) 18%, transparent)'
                        : state === 'now'
                          ? 'var(--private)'
                          : 'var(--surface2)',
                    color: state === 'done' ? 'var(--ok)' : '#fff',
                  }}
                >
                  {state === 'done' ? (
                    <Check size={11} />
                  ) : state === 'now' ? (
                    <span className="size-1.5 rounded-full bg-white" />
                  ) : null}
                </span>
                <span
                  style={{
                    color: state === 'todo' ? 'var(--text3)' : 'var(--text)',
                    fontWeight: state === 'now' ? 600 : 400,
                  }}
                >
                  {PHASE_LABEL[ph]}
                </span>
              </div>
            )
          })}
        </div>
        <p
          className="mt-4 flex gap-2 p-3 text-[12px]"
          style={{
            background: 'var(--surface2)',
            borderRadius: 'var(--r-row)',
            color: 'var(--text2)',
          }}
        >
          <Info size={14} className="mt-px shrink-0" />
          Your keys never leave this device. You can close this: the proof keeps running and the
          balance updates when it's sent.
        </p>
        <div className="pt-3">
          <Btn full onClick={close}>
            Keep running in background
          </Btn>
        </div>
      </div>
    )
  } else if (sheet?.flow === 'connect' && sheet.step === 'request') {
    sheetBody = (
      <div>
        <div className="mb-4 flex items-center justify-center">
          <AppMonogram text={DAPP.monogram} size={52} radius={16} />
          <span className="mx-2 flex gap-1">
            {[0, 1, 2].map((i) => (
              <motion.i
                key={i}
                className="size-1.5 rounded-full"
                style={{ background: 'var(--text3)' }}
                animate={{ opacity: [0.3, 1, 0.3] }}
                transition={{ repeat: Number.POSITIVE_INFINITY, duration: 1.2, delay: i * 0.2 }}
              />
            ))}
          </span>
          <span className="grid size-[52px] place-items-center rounded-2xl bg-black">
            <LogosMark size={26} />
          </span>
        </div>
        <div className="mb-4 text-center">
          <h3 className="text-[20px] font-semibold">{DAPP.name} wants to connect</h3>
          <span
            className="text-[12px]"
            style={{ fontFamily: 'var(--mono)', color: 'var(--text3)' }}
          >
            {DAPP.module} · v{DAPP.version}
          </span>
        </div>
        <p
          className="mb-3 flex gap-2 p-3 text-[12px]"
          style={{
            borderRadius: 'var(--r-row)',
            color: 'var(--warn)',
            background: 'color-mix(in srgb, var(--warn) 10%, transparent)',
          }}
        >
          <Info size={14} className="mt-px shrink-0" />
          Unsigned app. Basecamp can't confirm who published it.
        </p>
        <div className="mb-4 grid gap-2 text-[13px]">
          {[
            'See the accounts you choose and their balances',
            'Ask you to approve transactions',
          ].map((t) => (
            <span key={t} className="flex items-center gap-2">
              <Check size={14} style={{ color: 'var(--ok)' }} /> {t}
            </span>
          ))}
          <span className="flex items-center gap-2" style={{ color: 'var(--text2)' }}>
            <Lock size={14} /> It can never move funds without you
          </span>
        </div>
        <Btn tone="action" size="lg" full onClick={() => go('accounts')}>
          Choose accounts
        </Btn>
      </div>
    )
  } else if (sheet?.flow === 'connect' && sheet.step === 'accounts') {
    sheetBody = (
      <div>
        <Title sub="Testimonials posts from a public account.">Share which accounts?</Title>
        <div className="mb-4 grid gap-1.5">
          {ACCOUNTS.map((a) => {
            const on = a.id === 'a1'
            return (
              <div
                key={a.id}
                className="flex items-center gap-3 p-3"
                style={{
                  borderRadius: 'var(--r-row)',
                  background: on ? 'var(--surface2)' : 'transparent',
                  boxShadow: on ? 'inset 0 0 0 2px var(--action)' : 'inset 0 0 0 1px var(--line)',
                }}
              >
                <Identicon seed={a.seed} size={32} square={kind === 'ledger'} />
                <span className="min-w-0 flex-1">
                  <span className="block text-[14px] font-semibold">{a.label}</span>
                  <span className="text-[12px]" style={{ color: 'var(--text2)' }}>
                    {a.kind === 'private'
                      ? 'Private · needs its own consent'
                      : `${a.short} · ${fmt(a.id === 'a1' ? pub : a.balance)} LEZ`}
                  </span>
                </span>
                <span
                  className="grid size-5 place-items-center rounded-full"
                  style={{
                    background: on ? 'var(--action)' : 'transparent',
                    boxShadow: on ? 'none' : 'inset 0 0 0 1.5px var(--text3)',
                  }}
                >
                  {on && <Check size={12} color="#fff" />}
                </span>
              </div>
            )
          })}
        </div>
        <Btn
          tone="action"
          size="lg"
          full
          onClick={() => {
            setConnected(true)
            go('done')
            window.setTimeout(close, 1400)
          }}
        >
          Connect 1 account
        </Btn>
      </div>
    )
  } else if (sheet?.flow === 'connect' && sheet.step === 'done') {
    sheetBody = (
      <div className="flex flex-col items-center gap-3 py-6 text-center">
        <motion.span
          initial={{ scale: 0.4, opacity: 0 }}
          animate={{ scale: 1, opacity: 1 }}
          transition={{ type: 'spring', stiffness: 400, damping: 18 }}
          className="grid size-16 place-items-center rounded-full"
          style={{
            background: 'color-mix(in srgb, var(--action) 18%, transparent)',
            color: 'var(--action)',
          }}
        >
          <Check size={30} />
        </motion.span>
        <h3 className="text-[20px] font-semibold">Connected to {DAPP.name}</h3>
        <span className="text-[13px]" style={{ color: 'var(--text2)' }}>
          Sharing Public account 1. Taking you back…
        </span>
      </div>
    )
  }

  const first = sheet
    ? sheet.flow === 'send'
      ? sheet.step === 'amount' || sheet.step === 'proving'
      : sheet.step === 'request'
    : true
  const back = () => {
    if (!sheet) return
    if (sheet.flow === 'send' && sheet.step === 'review') go('amount', -1)
    if (sheet.flow === 'connect' && sheet.step === 'accounts') go('request', -1)
  }

  return (
    <div
      className="relative flex h-[780px] w-[380px] flex-col overflow-hidden"
      style={
        {
          ...vars,
          background: 'var(--bg)',
          color: 'var(--text)',
          fontFamily: 'var(--font)',
          borderRadius: 34,
          boxShadow: '0 0 0 1px rgba(255,255,255,0.08), 0 30px 80px rgba(0,0,0,0.5)',
        } as React.CSSProperties
      }
    >
      <div className="absolute inset-x-0 top-2.5 z-40 flex justify-center">
        <AnimatePresence>
          {island && (
            <motion.div
              initial={{ opacity: 0, y: -10 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -10 }}
            >
              <DynamicIsland
                view={island}
                onClick={
                  island === 'timer'
                    ? () => open({ flow: 'send', step: 'proving', dir: 1 })
                    : undefined
                }
              >
                {island === 'timer' && proof ? (
                  <div className="flex items-center gap-2.5 py-2 pl-2.5 pr-3.5 text-[12.5px] text-white">
                    <CircularProgress value={Math.round(proof.pct * 100)} size={18} thickness={3}>
                      <CircularProgressIndicator>
                        <CircularProgressTrack className="text-white/15" />
                        <CircularProgressRange className="text-[#a59fff]" />
                      </CircularProgressIndicator>
                    </CircularProgress>
                    <span className="font-semibold">Proving</span>
                    <span className="tabular-nums text-white/60">{formatLeft(proof.realLeft)}</span>
                  </div>
                ) : (
                  <div className="flex items-center gap-2 py-2 pl-2.5 pr-3.5 text-[12.5px] text-white">
                    <span className="grid size-[18px] place-items-center rounded-full bg-[#4bd166] text-black">
                      <Check size={11} />
                    </span>
                    <span className="font-semibold">Sent 12.50 LEZ privately</span>
                  </div>
                )}
              </DynamicIsland>
            </motion.div>
          )}
        </AnimatePresence>
      </div>
      <div className="flex-1 overflow-y-auto px-4 pb-6 pt-14">
        {kind === 'veil' ? veilHome : kind === 'tray' ? trayHome : ledgerHome}
      </div>
      <div className="flex items-center justify-center gap-2 px-4 pb-4">
        <button
          type="button"
          onClick={() => open({ flow: 'connect', step: 'request', dir: 1 })}
          className="rounded-full px-3 py-1.5 text-[12px] font-medium"
          style={{ background: 'var(--surface2)', color: 'var(--text2)' }}
        >
          {connected
            ? 'Testimonials connected · ask again'
            : 'Simulate: Testimonials asks to connect'}
        </button>
      </div>
      <Sheet
        open={sheet !== null}
        stepKey={
          sheet
            ? `${sheet.flow}-${sheet.step}-${proof && proof.phase === 'done' ? 'd' : ''}`
            : 'none'
        }
        dir={sheet?.dir ?? 1}
        isFirst={first}
        onClose={close}
        onBack={back}
        floating={kind === 'tray'}
      >
        {sheetBody}
      </Sheet>
    </div>
  )
}
