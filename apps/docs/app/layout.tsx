import { RootProvider } from 'fumadocs-ui/provider/next'
import type { Metadata } from 'next'
import './global.css'
import { Onest } from 'next/font/google'

const onest = Onest({
  subsets: ['latin'],
})

// Absolute base for OG images and canonical links. No domain is chosen yet:
// NEXT_PUBLIC_SITE_URL wins, then the Vercel production host, then localhost.
const siteUrl =
  process.env.NEXT_PUBLIC_SITE_URL ??
  (process.env.VERCEL_PROJECT_PRODUCTION_URL
    ? `https://${process.env.VERCEL_PROJECT_PRODUCTION_URL}`
    : 'http://localhost:3000')

export const metadata: Metadata = {
  metadataBase: new URL(siteUrl),
  title: { default: 'Logos Kit', template: '%s · Logos Kit' },
  description: 'A wallet and provider SDK for the Logos Execution Zone.',
}

export default function Layout({ children }: LayoutProps<'/'>) {
  return (
    <html lang="en" className={onest.className} suppressHydrationWarning>
      <body className="flex flex-col min-h-screen">
        <RootProvider theme={{ defaultTheme: 'dark' }}>{children}</RootProvider>
      </body>
    </html>
  )
}
