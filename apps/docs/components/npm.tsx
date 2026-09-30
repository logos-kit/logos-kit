import Image from 'next/image'

// The published TypeScript packages, with their live npm versions (read from
// the registry at build time and refreshed hourly; the row still renders if
// the registry can't be reached).
const PACKAGES = [
  {
    name: '@logos-kit/client',
    about: 'Typed client: node reads, LWS-0 wallet actions, the Basecamp transport',
  },
  {
    name: '@logos-kit/codec',
    about: 'Byte-exact LEZ 0.3 encoding; u128 amounts as strings, no BigInt',
  },
  { name: '@logos-kit/protocol', about: 'LWS-0: types, JSON Schema, error codes, test vectors' },
  { name: '@logos-kit/theme', about: 'Tray design tokens for CSS and QML' },
] as const

type Name = (typeof PACKAGES)[number]['name']

async function latest(name: string): Promise<string | null> {
  try {
    const r = await fetch(`https://registry.npmjs.org/${name.replace('/', '%2F')}/latest`, {
      next: { revalidate: 3600 },
    })
    if (!r.ok) return null
    const v = ((await r.json()) as { version?: string }).version
    return v && !v.includes('stage') ? v : null
  } catch {
    return null
  }
}

const npmUrl = (name: string) => `https://www.npmjs.com/package/${name}`

function NpmMark({ size = 18 }: { size?: number }) {
  return (
    <Image
      src="/logos/npm.svg"
      alt="npm"
      width={size}
      height={size}
      className="shrink-0 rounded-[3px]"
    />
  )
}

/** Every published package: npm logo, name, what it is, live version. */
export async function NpmPackages() {
  const versions = await Promise.all(PACKAGES.map((p) => latest(p.name)))
  return (
    <div className="not-prose my-6 overflow-hidden rounded-xl border border-fd-border">
      {PACKAGES.map((p, i) => (
        <a
          key={p.name}
          href={npmUrl(p.name)}
          target="_blank"
          rel="noreferrer"
          className="flex items-center gap-3 border-fd-border border-b px-4 py-3 transition-colors last:border-b-0 hover:bg-fd-accent"
        >
          <NpmMark />
          <div className="min-w-0 flex-1">
            <div className="font-medium font-mono text-sm">{p.name}</div>
            <div className="text-fd-muted-foreground text-xs">{p.about}</div>
          </div>
          {versions[i] && (
            <span className="shrink-0 rounded-full border border-fd-border px-2 py-0.5 font-mono text-fd-muted-foreground text-xs">
              v{versions[i]}
            </span>
          )}
        </a>
      ))}
    </div>
  )
}

/** One package: an inline npm link with its live version. */
export async function NpmBadge({ name }: { name: Name }) {
  const v = await latest(name)
  return (
    <a
      href={npmUrl(name)}
      target="_blank"
      rel="noreferrer"
      className="not-prose inline-flex items-center gap-2 rounded-full border border-fd-border bg-fd-card py-1 pr-3 pl-1.5 text-sm no-underline transition-colors hover:bg-fd-accent"
    >
      <NpmMark size={16} />
      <span className="font-mono">{name}</span>
      {v && <span className="font-mono text-fd-muted-foreground text-xs">v{v}</span>}
    </a>
  )
}
