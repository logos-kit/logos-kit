import Image from 'next/image'
import Link from 'next/link'
import { CodeShowcase } from '@/components/landing/code-showcase'
import { Faq } from '@/components/landing/faq'
import { Footer } from '@/components/landing/footer'
import { NetworkStatus } from '@/components/landing/network-status'
import { Phone } from '@/components/landing/phone'
import { ScriptCopy } from '@/components/landing/script-copy'
import { cn } from '@/lib/cn'

// Ledger landing (Refero: family.co and ctrl.xyz homepages): a centred bold
// promise with a black and a grey pill, the real wallet in dark device
// frames, then alternating feature blocks that each show the real screen, the
// developer path, a testimonial call, the FAQ. White / black; colour only for
// status; one quiet tint per feature panel.

const qml = `import "LogosKit"

LogosKit { id: kit; visible: root.visible }

// The wallet asks the user which account to share.
kit.api.connect({ accountKinds: ["public", "private"] })
    .then(function (s) { account = s.accounts[0].address })

// The user approves in the wallet. You get a handle and follow it.
// Amounts are lepta: parseUnits("0.5", 9) is half an LGO.
kit.api.transfer(account, to, "500000000").then(function (r) {
    kit.api.watchTransaction(r.handle, function (s) {
        if (s.lifecycle === "included")
            done = s.outcome === "success"   // proved from chain state
    })
})`

const ts = `import { createClient, http, nodeActions } from '@logos-kit/client'

// The official testnet, through the CORS relay for browser code.
const lez = createClient({
  transport: http('https://lez-testnet.84.46.247.92.sslip.io'),
  chain: 'lez:testnet',
}).extend(nodeActions)

console.log('block', await lez.getBlockNumber())`

const stack = [
  { src: '/logos/rust.svg', dark: '/logos/rust_dark.svg', name: 'Rust engine' },
  { src: '/logos/qt.svg', name: 'Qt / QML' },
  { src: '/logos/typescript.svg', name: 'TypeScript client' },
  { src: '/logos/npm.svg', name: '@logos-kit on npm', href: 'https://www.npmjs.com/org/logos-kit' },
  { src: '/logos/nix.svg', name: 'Nix builds' },
  { src: '/logos/risc0.png', name: 'RISC Zero proofs', mono: true },
]

/** The wallet's sheets, cropped from the QML renders (width, height). */
const SHEETS: Record<string, [number, number]> = {
  'sheet-approval': [920, 1195],
  'sheet-receive': [920, 1245],
  'sheet-proving': [920, 1337],
  'sheet-review': [920, 1067],
}

function Check() {
  return (
    <svg
      viewBox="0 0 24 24"
      aria-hidden
      className="mt-[3px] size-[18px] shrink-0 text-[var(--lk-ok)]"
    >
      <path
        d="M5 12.5l4.5 4.5L19 7.5"
        fill="none"
        stroke="currentColor"
        strokeWidth="2.4"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  )
}

/** One feature: the claim and its proof points beside the real screen. */
function Feature({
  eyebrow,
  title,
  body,
  points,
  shot,
  alt,
  tint,
  flip,
}: {
  eyebrow: string
  title: string
  body: string
  points: string[]
  shot: string
  alt: string
  tint: string
  flip?: boolean
}) {
  const [w, h] = SHEETS[shot] ?? [920, 1200]
  return (
    <section className="mx-auto grid w-full max-w-6xl items-center gap-10 px-5 py-14 md:grid-cols-2 md:gap-16 md:py-20">
      <div className={cn(flip && 'md:order-2')}>
        <div className="font-medium text-[13px] text-fd-muted-foreground">{eyebrow}</div>
        <h2 className="mt-3 text-balance font-semibold text-[40px] leading-[1] tracking-[-0.035em] md:text-[56px]">
          {title}
        </h2>
        <p className="mt-5 max-w-md text-pretty text-[17px] text-fd-muted-foreground leading-relaxed">
          {body}
        </p>
        <ul className="mt-7 flex flex-col gap-3.5">
          {points.map((p) => (
            <li key={p} className="flex gap-3 text-[15px] leading-snug">
              <Check />
              <span>{p}</span>
            </li>
          ))}
        </ul>
      </div>
      <div
        className={cn(
          'relative flex justify-center overflow-hidden rounded-[40px] px-6 pt-12 md:pt-14',
          tint,
          flip && 'md:order-1',
        )}
      >
        <Image
          src={`/shots/ledger/${shot}.webp`}
          alt={alt}
          width={w}
          height={h}
          sizes="360px"
          className="-mb-28 h-auto w-[300px] md:w-[360px]"
        />
      </div>
    </section>
  )
}

const faq = [
  {
    q: 'Which network does it use?',
    a: (
      <>
        The official LEZ testnet 0.3 (<code>https://testnet.lez.logos.co</code>, LEZ v0.3.0). It is
        the default in the wallet, the CLI and the SDK. Testnets only: tokens have no value.{' '}
        <Link
          href="/docs/concepts/networks"
          className="text-fd-foreground underline underline-offset-4"
        >
          Networks
        </Link>
      </>
    ),
  },
  {
    q: 'What is LGO?',
    a: 'LOGOS, the native token, written LGO. 1 LGO is 10⁹ lepta, its smallest unit. The wallet shows LGO; apps and the SDK pass lepta, so nothing is ever rounded.',
  },
  {
    q: 'How do I get test LGO?',
    a: (
      <>
        Press <strong className="text-fd-foreground">Test LGO</strong> in the wallet: 1 LGO, once an
        hour per account. Apps can open the same sheet with <code>requestFunds</code>. A private
        account is funded through a public one, then shielded.
      </>
    ),
  },
  {
    q: 'Can an app see my private balance?',
    a: 'Only if you tick that account and allow it when you connect. Even then it can read, never spend: every transaction still needs your approval in the wallet.',
  },
  {
    q: 'Is it safe to use?',
    a: (
      <>
        Keys are encrypted at rest and never leave the wallet; approvals live in the wallet's
        engine, not in apps. It is unaudited and runs on testnets only.{' '}
        <Link
          href="/docs/wallet/security"
          className="text-fd-foreground underline underline-offset-4"
        >
          Security model
        </Link>
      </>
    ),
  },
]

export default function HomePage() {
  return (
    <main className="flex flex-1 flex-col overflow-x-clip bg-fd-background">
      {/* -- hero: Family's centred promise and two pills ------------------------ */}
      <section className="mx-auto w-full max-w-6xl px-5 pt-14 text-center md:pt-24">
        <div
          className="lk-rise"
          style={{ animation: 'lk-rise 700ms cubic-bezier(0.16,1,0.3,1) both' }}
        >
          <NetworkStatus className="mx-auto mb-8" />
          <h1 className="mx-auto max-w-4xl text-balance font-semibold text-[52px] leading-[0.92] tracking-[-0.05em] sm:text-[78px] md:text-[104px]">
            The private wallet for Logos.
          </h1>
          <p className="mx-auto mt-7 max-w-xl text-pretty text-[18px] text-fd-muted-foreground leading-relaxed">
            Public and private accounts, approvals that say exactly what they do, and the SDK your
            Basecamp app uses to ask for them. Keys never leave the wallet.
          </p>
          <div className="mt-9 flex flex-wrap justify-center gap-3">
            <Link
              href="/docs/wallet/install"
              className="rounded-full bg-fd-foreground px-7 py-3.5 font-semibold text-[15px] text-fd-background transition active:scale-[0.97]"
            >
              Install the wallet
            </Link>
            <Link
              href="/docs/getting-started/quickstart"
              className="rounded-full bg-fd-card px-7 py-3.5 font-semibold text-[15px] transition hover:bg-fd-secondary active:scale-[0.97]"
            >
              Build an app
            </Link>
          </div>
        </div>

        {/* The real wallet, three screens (rendered from the QML wallet). */}
        <div className="relative mt-16 flex items-start justify-center gap-6 md:mt-20">
          <Phone
            src="/shots/ledger/receive-dark.webp"
            alt="Receive privately: the account's receive code as a QR"
            className="hidden translate-y-14 -rotate-6 opacity-95 md:block"
          />
          <Phone
            src="/shots/ledger/home-dark.webp"
            alt="Wallet home: the balance in LGO, Send, Receive and Test LGO, tokens and activity"
            className="relative z-10"
            priority
          />
          <Phone
            src="/shots/ledger/proving-dark.webp"
            alt="Sending privately: the proof runs on this device, step by step"
            className="hidden translate-y-14 rotate-6 opacity-95 md:block"
          />
        </div>
      </section>

      {/* -- features: each claim beside its real screen ----------------------- */}
      <Feature
        eyebrow="Approvals"
        title="Every approval says what it does."
        body="Decoded from the exact message being signed, never from what the app says it does."
        points={[
          'Who is asking: the app, its name checked by Basecamp',
          'What moves: the amount, the asset and the full destination',
          'Which program: source-verified or flagged, and whether it can still change',
        ]}
        shot="sheet-approval"
        alt="An app's request in the wallet: Send 0.000000005 LGO to Savings, with the network fee, the account it comes from and Reject / Approve"
        tint="bg-[#e9f0fb] dark:bg-fd-card"
      />
      <Feature
        flip
        eyebrow="Privacy"
        title="Private by default."
        body="Private balances only you can see. Private sends are proved on your own machine, before anything leaves it."
        points={[
          'As many public and private accounts as you like',
          'Receive privately with a code that reveals nothing about your balance',
          'Apps can read a private balance only if you tick it, and never spend',
        ]}
        shot="sheet-receive"
        alt="Receive privately: the private account's receive code as a QR, which reveals nothing about the balance"
        tint="bg-[#f3eedf] dark:bg-fd-card"
      />
      <Feature
        eyebrow="Outcomes"
        title="Included isn't done."
        body="LEZ includes failed transactions too. Logos Kit checks the effect against chain state before it says success."
        points={[
          'Success only when the balances moved the way you approved',
          'A slow network keeps the send pending, never silently failed',
          'Every step on screen, with the block it landed in',
        ]}
        shot="sheet-proving"
        alt="Sending privately: a ring with the elapsed time and the steps Approved, Preparing, Proving on this device, Signing, Waiting for a block"
        tint="bg-[#eef3ec] dark:bg-fd-card"
      />

      {/* -- developers ---------------------------------------------------------- */}
      <section className="mx-auto w-full max-w-6xl px-5 py-14 md:py-20">
        <div className="max-w-2xl">
          <div className="font-medium text-[13px] text-fd-muted-foreground">
            For Basecamp builders
          </div>
          <h2 className="mt-3 text-balance font-semibold text-[40px] leading-[1] tracking-[-0.035em] md:text-[56px]">
            A wallet in your app in ten minutes.
          </h2>
          <p className="mt-5 text-pretty text-[17px] text-fd-muted-foreground leading-relaxed">
            Start from the template: connect, balances, test funds in the flow and a receipt,
            already wired. Your app asks; the wallet shows the user exactly what they approve.
          </p>
        </div>
        <ScriptCopy
          className="mt-8 w-full max-w-xl"
          commands={{
            'Basecamp app': 'nix flake init -t github:logos-kit/logos-kit#dapp',
            'npm · TypeScript': 'npm install @logos-kit/client @logos-kit/codec',
          }}
          icons={{ 'npm · TypeScript': '/logos/npm.svg' }}
        />
        <div className="mt-8">
          <CodeShowcase
            files={[
              { name: 'Main.qml', lang: 'qml', code: qml },
              { name: 'read.ts', lang: 'ts', code: ts },
            ]}
          />
        </div>
        <div className="mt-6 flex flex-wrap gap-x-6 gap-y-2 text-[15px]">
          <Link
            href="/docs/getting-started/quickstart"
            className="font-semibold underline underline-offset-4"
          >
            Start the quickstart
          </Link>
          <Link
            href="/docs/sdk/qml"
            className="text-fd-muted-foreground underline underline-offset-4"
          >
            Every QML call
          </Link>
          <Link
            href="/docs/guides/send"
            className="text-fd-muted-foreground underline underline-offset-4"
          >
            Send a transaction
          </Link>
        </div>
      </section>

      {/* -- testimonial call ------------------------------------------------------ */}
      <section className="mx-auto w-full max-w-6xl px-5 py-8">
        <div className="grid items-center gap-8 overflow-hidden rounded-[40px] bg-fd-foreground px-8 pt-10 text-fd-background md:grid-cols-[1.1fr_1fr] md:px-14 md:pt-14">
          <div className="pb-10 md:pb-14">
            <h2 className="text-balance font-semibold text-[34px] leading-[1.02] tracking-[-0.03em] md:text-[46px]">
              Tried it? Leave a testimonial.
            </h2>
            <p className="mt-4 max-w-md text-[16px] leading-relaxed opacity-70">
              One sentence about what you used it for, stored on the Logos testnet. It helps this
              independent project's λPrize entry.
            </p>
            <Link
              href="/docs/guides/testimonial"
              className="mt-7 inline-block rounded-full bg-fd-background px-6 py-3 font-semibold text-[15px] text-fd-foreground transition active:scale-[0.97]"
            >
              How it works
            </Link>
          </div>
          <div className="flex justify-center">
            <Image
              src="/shots/ledger/testimonial-compose.webp"
              alt="The Testimonials app: say what you use it for, with suggestions"
              width={1040}
              height={1386}
              sizes="380px"
              className="w-[340px] rounded-t-[32px] md:w-[380px]"
            />
          </div>
        </div>
      </section>

      {/* -- FAQ ---------------------------------------------------------------------- */}
      <section className="mx-auto grid w-full max-w-6xl gap-10 px-5 py-14 md:grid-cols-[1fr_1.6fr] md:py-20">
        <h2 className="text-balance font-semibold text-[40px] leading-[1] tracking-[-0.035em] md:text-[56px]">
          Questions
        </h2>
        <Faq items={faq} />
      </section>

      {/* -- built with ------------------------------------------------------------- */}
      <section className="mx-auto w-full max-w-6xl px-5 pb-16">
        <div className="flex flex-wrap items-center justify-center gap-x-8 gap-y-4 text-[13px] text-fd-muted-foreground">
          {stack.map((s) => {
            const logo = (
              <span key={s.name} className="flex items-center gap-2">
                <Image
                  src={s.src}
                  alt=""
                  width={18}
                  height={18}
                  className={cn('size-[18px]', s.dark && 'dark:hidden', s.mono && 'dark:invert')}
                />
                {s.dark ? (
                  <Image
                    src={s.dark}
                    alt=""
                    width={18}
                    height={18}
                    className="hidden size-[18px] dark:block"
                  />
                ) : null}
                {s.name}
              </span>
            )
            return s.href ? (
              <a key={s.name} href={s.href} className="hover:text-fd-foreground">
                {logo}
              </a>
            ) : (
              logo
            )
          })}
        </div>
      </section>

      <Footer />
    </main>
  )
}
