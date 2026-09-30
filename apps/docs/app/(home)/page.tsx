import Image from 'next/image'
import Link from 'next/link'
import { BorderBeam } from '@/components/landing/border-beam'
import { CodeShowcase } from '@/components/landing/code-showcase'
import { ContainerScroll } from '@/components/landing/container-scroll'
import { Flow } from '@/components/landing/flow'
import { Footer } from '@/components/landing/footer'
import { HeroCollage } from '@/components/landing/hero-collage'
import { NetworkStatus } from '@/components/landing/network-status'
import { ScriptCopy } from '@/components/landing/script-copy'
import { Status } from '@/components/landing/status'
import { cn } from '@/lib/cn'

const qml = `import "LogosKit"

LogosKit { id: kit; visible: root.visible }

// The wallet asks the user which account to share.
kit.api.connect({ accountKinds: ["public", "private"] })
    .then(function (s) { account = s.accounts[0].address })

// The user approves in the wallet. You get a handle and follow it.
kit.api.transfer(account, to, "42").then(function (r) {
    kit.api.watchTransaction(r.handle, function (s) {
        if (s.lifecycle === "included")
            done = s.outcome === "success"   // proved from chain state
    })
})`

const ts = `import { createClient, http, nodeActions } from '@logos-kit/client'
import { formatUnits } from '@logos-kit/codec'

const lez = createClient({
  transport: http('https://lez.84.46.247.92.sslip.io'),
  chain: 'lez:preview',
}).extend(nodeActions)

const height = await lez.getBlockNumber()
console.log(\`block \${height}\`, formatUnits('1500000', 6)) // "1.5"`

const stack = [
  { src: '/logos/rust.svg', dark: '/logos/rust_dark.svg', name: 'Rust engine' },
  { src: '/logos/qt.svg', name: 'Qt / QML' },
  { src: '/logos/typescript.svg', name: 'TypeScript client' },
  { src: '/logos/npm.svg', name: '@logos-kit on npm', href: 'https://www.npmjs.com/org/logos-kit' },
  { src: '/logos/nix.svg', name: 'Nix builds' },
  { src: '/logos/risc0.png', name: 'RISC Zero proofs', mono: true },
]

function Cell({
  className,
  delay,
  eyebrow,
  title,
  body,
  children,
}: {
  className?: string
  delay: number
  eyebrow: string
  title: string
  body: string
  children?: React.ReactNode
}) {
  return (
    <div
      className={cn(
        'lk-rise group relative flex flex-col overflow-hidden rounded-3xl border border-fd-border bg-fd-card',
        className,
      )}
      style={{ animation: `lk-rise 700ms cubic-bezier(0.16,1,0.3,1) ${delay}ms both` }}
    >
      <div className="p-6 md:p-7">
        <div className="font-medium text-[11px] text-fd-muted-foreground uppercase tracking-[0.14em]">
          {eyebrow}
        </div>
        <h3 className="mt-2 font-semibold text-lg tracking-tight">{title}</h3>
        <p className="mt-1.5 max-w-md text-fd-muted-foreground text-sm leading-relaxed">{body}</p>
      </div>
      {children ? <div className="relative mt-auto">{children}</div> : null}
    </div>
  )
}

/** A product panel cropped into a bento cell, fading into the card. */
function Crop({
  name,
  alt,
  top = 0,
  height = 300,
}: {
  name: string
  alt: string
  top?: number
  height?: number
}) {
  return (
    <div
      className="relative mx-6 overflow-hidden rounded-t-2xl border border-fd-border border-b-0 bg-black"
      style={{ height }}
    >
      <Image
        src={`/shots/${name}.webp`}
        alt={alt}
        width={960}
        height={1300}
        className="w-full transition-transform duration-700 ease-out group-hover:-translate-y-2"
        style={{ marginTop: -top }}
      />
      <div className="pointer-events-none absolute inset-x-0 bottom-0 h-16 bg-gradient-to-t from-fd-card to-transparent" />
    </div>
  )
}

export default function HomePage() {
  return (
    <main className="flex flex-1 flex-col overflow-x-clip">
      <div className="pointer-events-none absolute inset-x-0 top-0 -z-10 h-[46rem] bg-[radial-gradient(60%_50%_at_50%_0%,rgb(56_152_255/0.16),transparent_70%),radial-gradient(40%_40%_at_85%_10%,rgb(122_112_255/0.12),transparent_70%)]" />

      <ContainerScroll
        title={
          <div className="flex flex-col items-center px-4">
            <NetworkStatus className="mb-7" />
            <h1 className="max-w-4xl text-balance font-semibold text-[2.6rem] leading-[1.05] tracking-[-0.03em] md:text-[4.25rem]">
              The private wallet kit for the Logos Execution Zone
            </h1>
            <p className="mt-6 max-w-2xl text-balance text-fd-muted-foreground text-lg leading-relaxed md:text-xl">
              A wallet with public and private accounts, and the SDK your Basecamp app uses to ask
              it for things. Keys stay in the wallet. Every approval says what it does.
            </p>
            <div className="mt-9 flex flex-wrap justify-center gap-3">
              <Link
                href="/docs/getting-started/quickstart"
                className="rounded-full bg-fd-foreground px-6 py-3 font-medium text-fd-background text-sm transition hover:opacity-90 active:scale-[0.97]"
              >
                Build an app in 10 minutes
              </Link>
              <Link
                href="/docs/wallet/install"
                className="rounded-full border border-fd-border bg-fd-card/60 px-6 py-3 font-medium text-sm backdrop-blur transition hover:bg-fd-secondary active:scale-[0.97]"
              >
                Install the wallet
              </Link>
            </div>
            <ScriptCopy
              className="mt-9 w-full max-w-xl text-left"
              commands={{
                'Basecamp app': 'nix flake init -t github:logos-kit/logos-kit#dapp',
                'npm · TypeScript': 'npm install @logos-kit/client @logos-kit/codec',
              }}
              icons={{ 'npm · TypeScript': '/logos/npm.svg' }}
            />
          </div>
        }
      >
        <HeroCollage />
      </ContainerScroll>

      <section className="mx-auto w-full max-w-6xl px-6 pt-24 pb-8 md:pt-10">
        <div className="text-center">
          <h2 className="font-semibold text-3xl tracking-tight md:text-4xl">
            Apps ask. People decide.
          </h2>
          <p className="mx-auto mt-3 max-w-xl text-fd-muted-foreground">
            Anything a user sees goes through Basecamp, which attests which app is asking. Reads go
            straight to the wallet. No app ever holds a key.
          </p>
        </div>
        <div className="mx-auto mt-6 max-w-3xl">
          <Flow />
        </div>
      </section>

      <section className="mx-auto w-full max-w-6xl px-6 py-16">
        <div className="grid auto-rows-[minmax(0,auto)] gap-4 md:grid-cols-6">
          <Cell
            className="md:col-span-4 md:row-span-2"
            delay={0}
            eyebrow="Approvals"
            title="Every approval says what it does"
            body="Decoded from the exact message being signed: who pays whom, which program, whether its source is verified and whether it can still change. With the fee cap and the requesting app."
          >
            <Crop
              name="wallet-approval"
              alt="The wallet's approval sheet for a testimonial post"
              height={420}
            />
          </Cell>
          <Cell
            className="md:col-span-2"
            delay={80}
            eyebrow="Privacy"
            title="Private by default"
            body="Private balances only you can see. Private transfers are proved on your own machine."
          >
            <Crop
              name="wallet-proving"
              alt="A private send proving on the device"
              top={110}
              height={200}
            />
          </Cell>
          <Cell
            className="md:col-span-2"
            delay={160}
            eyebrow="Outcomes"
            title="Included isn't done"
            body="LEZ includes failed transactions. The wallet proves the effect from chain state before it says success."
          >
            <div className="flex flex-wrap gap-2 px-6 pb-7">
              <Status variant="ok">success</Status>
              <Status variant="danger">failure</Status>
              <Status variant="warn">unknown · re-check</Status>
              <Status variant="priv" pulse>
                proving 95%
              </Status>
            </div>
          </Cell>
          <Cell
            className="md:col-span-3"
            delay={240}
            eyebrow="Worked examples"
            title="Real apps to copy"
            body="A testimonial app and a faucet with every state designed: loading, pending, rate-limited, unconfirmed, failed."
          >
            <Crop
              name="testimonial-compose"
              alt="The testimonial app composing a post"
              top={40}
              height={220}
            />
          </Cell>
          <Cell
            className="md:col-span-3"
            delay={320}
            eyebrow="Test funds"
            title="Funds without leaving your app"
            body="requestFunds opens the wallet's faucet sheet, rate limits and all. Private accounts get funded, then shielded."
          >
            <Crop
              name="faucet-rate-limited"
              alt="The faucet app with a rate-limit countdown"
              top={40}
              height={220}
            />
          </Cell>
        </div>
      </section>

      <section className="mx-auto grid w-full max-w-6xl items-center gap-10 px-6 py-16 md:grid-cols-[1fr_1.25fr]">
        <div>
          <div className="font-medium text-[11px] text-fd-muted-foreground uppercase tracking-[0.14em]">
            QML in Basecamp · TypeScript for tools
          </div>
          <h2 className="mt-2 font-semibold text-3xl tracking-tight md:text-4xl">
            Ask, approve, follow
          </h2>
          <p className="mt-4 text-fd-muted-foreground leading-relaxed">
            A proposal resolves when the user approves it, with a handle. The transaction proves,
            lands and gets its outcome after that; your app follows the handle and shows each step.
            Apps call the wallet from QML. The TypeScript client (Node and transport tooling,
            byte-exact LEZ encoding, no <code>BigInt</code>) reads the chain from scripts and tools.
            Web and React Native connect kits are planned.
          </p>
          <div className="mt-6 flex flex-wrap gap-x-6 gap-y-2 font-medium text-sm">
            <Link href="/docs/guides/send" className="text-[var(--lk-action)]">
              Send a transaction →
            </Link>
            <Link href="/docs/sdk/qml" className="text-[var(--lk-action)]">
              Every QML call →
            </Link>
          </div>
        </div>
        <CodeShowcase
          files={[
            { name: 'Main.qml', lang: 'qml', code: qml },
            { name: 'read.ts (Node)', lang: 'ts', code: ts },
          ]}
        />
      </section>

      <section className="mx-auto w-full max-w-6xl px-6 py-10">
        <div className="text-center font-medium text-[11px] text-fd-muted-foreground uppercase tracking-[0.14em]">
          Built on
        </div>
        <div className="mt-6 flex flex-wrap items-center justify-center gap-x-10 gap-y-6">
          {stack.map((s) => (
            <a
              key={s.name}
              href={s.href}
              target={s.href ? '_blank' : undefined}
              rel={s.href ? 'noreferrer' : undefined}
              className={cn(
                'flex items-center gap-2.5 text-fd-muted-foreground text-sm',
                s.href && 'transition-colors hover:text-fd-foreground',
              )}
            >
              {s.dark ? (
                <>
                  <Image
                    src={s.src}
                    alt=""
                    width={24}
                    height={24}
                    className="h-6 w-auto dark:hidden"
                  />
                  <Image
                    src={s.dark}
                    alt=""
                    width={24}
                    height={24}
                    className="hidden h-6 w-auto dark:block"
                  />
                </>
              ) : (
                <Image
                  src={s.src}
                  alt=""
                  width={24}
                  height={24}
                  className={cn('h-6 w-auto', s.mono && 'rounded-md grayscale dark:invert')}
                />
              )}
              {s.name}
            </a>
          ))}
        </div>
      </section>

      <section className="mx-auto w-full max-w-6xl px-6 py-20">
        <div className="relative overflow-hidden rounded-[2rem] border border-fd-border bg-fd-card px-8 py-14 text-center md:py-20">
          <BorderBeam size={300} duration={16} />
          <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(60%_80%_at_50%_0%,rgb(56_152_255/0.12),transparent_70%)]" />
          <h2 className="relative mx-auto max-w-2xl text-balance font-semibold text-3xl tracking-tight md:text-5xl">
            Your first Basecamp app, sending LEZ, in ten minutes
          </h2>
          <p className="relative mx-auto mt-4 max-w-lg text-fd-muted-foreground">
            Start from the template: connect, balance, in-flow test funds and a receipt, already
            wired.
          </p>
          <div className="relative mt-8 flex flex-wrap justify-center gap-3">
            <Link
              href="/docs/getting-started/quickstart"
              className="rounded-full bg-fd-foreground px-6 py-3 font-medium text-fd-background text-sm transition hover:opacity-90 active:scale-[0.97]"
            >
              Start the quickstart
            </Link>
            <Link
              href="/docs/guides/testimonial"
              className="rounded-full border border-fd-border px-6 py-3 font-medium text-sm transition hover:bg-fd-secondary active:scale-[0.97]"
            >
              Read a worked example
            </Link>
          </div>
        </div>
      </section>

      <Footer />
    </main>
  )
}
