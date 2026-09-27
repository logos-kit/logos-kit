import Image from 'next/image'
import Link from 'next/link'
import { ScriptCopy } from '@/components/landing/script-copy'

const features = [
  {
    title: 'Keys stay in the wallet',
    body: 'Apps ask; the user approves in the wallet. No app, UI or shell ever holds a key.',
  },
  {
    title: 'Private by default',
    body: 'Public and private accounts. Private transfers are proved on your own machine.',
  },
  {
    title: 'Approvals you can read',
    body: 'Decoded effects, the fee, and whether the program is source-verified and immutable.',
  },
  {
    title: 'Built for Basecamp',
    body: 'Apps reach the wallet through Basecamp intents; the shell attests who is asking.',
  },
  {
    title: 'One SDK, QML and TypeScript',
    body: 'Connect, read, propose, follow. Same calls in a Basecamp app, a script or the web.',
  },
  {
    title: 'Real apps to copy',
    body: 'A testimonial app and a faucet, every state handled, plus a template you can init.',
  },
]

const code = `import "LogosKit"

LogosKit { id: kit; visible: root.visible }

// The wallet asks the user which account to share.
kit.api.connect({ accountKinds: ["public"] }).then(function (s) {
    account = s.accounts[0].address
})

// The user approves in the wallet; follow the handle.
kit.api.transfer(account, to, "42").then(function (r) {
    kit.api.watchTransaction(r.handle, function (s) {
        status = s.lifecycle          // submitted → included
    })
})`

export default function HomePage() {
  return (
    <main className="flex flex-1 flex-col">
      <section className="mx-auto flex w-full max-w-6xl flex-col items-center px-6 pt-20 pb-16 text-center md:pt-28">
        <span className="mb-6 inline-flex items-center gap-2 rounded-full border border-fd-border bg-fd-card px-3 py-1 text-fd-muted-foreground text-xs">
          <span className="size-1.5 rounded-full bg-[var(--lk-ok)]" />
          Logos Execution Zone · testnet
        </span>
        <h1 className="max-w-3xl font-semibold text-4xl tracking-tight md:text-6xl">
          The wallet kit for the Logos Execution Zone
        </h1>
        <p className="mt-5 max-w-xl text-fd-muted-foreground text-lg">
          A wallet for public and private accounts, and the SDK your Basecamp app uses to ask it for
          things.
        </p>
        <div className="mt-8 flex flex-wrap justify-center gap-3">
          <Link
            href="/docs/quickstart"
            className="rounded-full bg-fd-foreground px-6 py-3 font-medium text-fd-background text-sm transition active:scale-[0.97]"
          >
            Build an app
          </Link>
          <Link
            href="/docs"
            className="rounded-full border border-fd-border px-6 py-3 font-medium text-sm transition hover:bg-fd-secondary active:scale-[0.97]"
          >
            Read the docs
          </Link>
        </div>
        <ScriptCopy
          className="mt-10 text-left"
          commands={{
            'Basecamp app': 'nix flake init -t github:logos-kit/logos-kit#dapp',
            TypeScript: 'pnpm add @logos-kit/client @logos-kit/codec',
          }}
        />
      </section>

      <section className="mx-auto grid w-full max-w-6xl items-start gap-4 px-6 md:grid-cols-[1.6fr_1fr]">
        <figure className="overflow-hidden rounded-3xl border border-fd-border bg-fd-card">
          <Image
            src="/shots/testimonial-basecamp.png"
            alt="The testimonial app in Basecamp after a post landed on chain"
            width={2624}
            height={1436}
            className="h-auto w-full"
            priority
          />
          <figcaption className="border-fd-border border-t px-5 py-3 text-fd-muted-foreground text-sm">
            The testimonial app in Basecamp: posted, included, counted.
          </figcaption>
        </figure>
        <figure className="overflow-hidden rounded-3xl border border-fd-border bg-fd-card">
          <Image
            src="/shots/wallet-approval.png"
            alt="The wallet's approval sheet for a testimonial post"
            width={880}
            height={1380}
            className="mx-auto h-auto w-full max-w-sm"
          />
          <figcaption className="border-fd-border border-t px-5 py-3 text-fd-muted-foreground text-sm">
            What the user approves: decoded, verified, with the fee.
          </figcaption>
        </figure>
      </section>

      <section className="mx-auto w-full max-w-6xl px-6 py-20">
        <div className="grid gap-px overflow-hidden rounded-3xl border border-fd-border bg-fd-border sm:grid-cols-2 lg:grid-cols-3">
          {features.map((f) => (
            <div key={f.title} className="bg-fd-background p-7">
              <h3 className="font-semibold">{f.title}</h3>
              <p className="mt-2 text-fd-muted-foreground text-sm leading-relaxed">{f.body}</p>
            </div>
          ))}
        </div>
      </section>

      <section className="mx-auto grid w-full max-w-6xl items-center gap-10 px-6 pb-24 md:grid-cols-2">
        <div>
          <h2 className="font-semibold text-3xl tracking-tight">Ask, approve, follow</h2>
          <p className="mt-4 text-fd-muted-foreground leading-relaxed">
            A proposal resolves when the user approves it, with a handle. The transaction proves,
            lands and finalizes after that; your app follows the handle and shows each step.
          </p>
          <Link
            href="/docs/sdk/qml"
            className="mt-6 inline-block font-medium text-[var(--lk-action)] text-sm"
          >
            Every call in the QML SDK →
          </Link>
        </div>
        <pre className="overflow-x-auto rounded-3xl border border-fd-border bg-fd-card p-6 font-mono text-[13px] leading-relaxed">
          {code}
        </pre>
      </section>
    </main>
  )
}
