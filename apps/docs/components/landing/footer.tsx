// Layout from the 21st.dev "Minimal Footer" (efferd, id 7264), with our own
// links, no social icons.
import Image from 'next/image'
import Link from 'next/link'

const cols = [
  {
    title: 'Build',
    links: [
      ['Quickstart', '/docs/getting-started/quickstart'],
      ['QML SDK', '/docs/sdk/qml'],
      ['TypeScript client', '/docs/sdk/client'],
      ['Build with AI', '/docs/ai'],
    ],
  },
  {
    title: 'Wallet',
    links: [
      ['Install', '/docs/wallet/install'],
      ['CLI', '/docs/wallet/cli'],
      ['Networks', '/docs/concepts/networks'],
      ['Security model', '/docs/wallet/security'],
    ],
  },
  {
    title: 'Project',
    links: [
      ['GitHub', 'https://github.com/logos-kit/logos-kit'],
      ['Catalog', 'https://github.com/logos-kit/logos-kit-modules'],
      ['Changelog', '/docs/changelog'],
      ['Troubleshooting', '/docs/help/troubleshooting'],
    ],
  },
] as const

export function Footer() {
  return (
    <footer className="border-fd-border border-t">
      <div className="mx-auto grid w-full max-w-6xl gap-10 px-6 py-14 md:grid-cols-[1.4fr_repeat(3,1fr)]">
        <div className="space-y-4">
          <span className="inline-flex items-center gap-2 font-semibold">
            <Image
              src="/logos-mark-white.svg"
              alt=""
              width={16}
              height={18}
              className="hidden dark:block"
            />
            <Image
              src="/logos-mark-black.svg"
              alt=""
              width={16}
              height={18}
              className="dark:hidden"
            />
            Logos Kit
          </span>
          <p className="max-w-xs text-fd-muted-foreground text-sm leading-relaxed">
            Logos Kit: a wallet and an app SDK for the Logos Execution Zone. Built for Logos λPrize
            LP-0021. MIT or Apache-2.0.
          </p>
        </div>
        {cols.map((c) => (
          <div key={c.title}>
            <div className="mb-3 font-medium text-sm">{c.title}</div>
            <ul className="space-y-2">
              {c.links.map(([label, href]) => (
                <li key={href}>
                  <Link
                    href={href}
                    className="text-fd-muted-foreground text-sm transition hover:text-fd-foreground"
                  >
                    {label}
                  </Link>
                </li>
              ))}
            </ul>
          </div>
        ))}
      </div>
      <div className="mx-auto w-full max-w-6xl px-6 pb-10 text-fd-muted-foreground text-xs">
        Testnets only. Unaudited. An independent project built for Logos λPrize LP-0021.
      </div>
    </footer>
  )
}
