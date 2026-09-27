import { RootProvider } from 'fumadocs-ui/provider/next'
import './global.css'
import { Onest } from 'next/font/google'

const onest = Onest({
  subsets: ['latin'],
})

export default function Layout({ children }: LayoutProps<'/'>) {
  return (
    <html lang="en" className={onest.className} suppressHydrationWarning>
      <body className="flex flex-col min-h-screen">
        <RootProvider theme={{ defaultTheme: 'dark' }}>{children}</RootProvider>
      </body>
    </html>
  )
}
