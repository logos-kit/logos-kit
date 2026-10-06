'use client'

// Live status of the official LEZ testnet: the sequencer's latest block, read
// from the browser through Logos Kit's CORS relay (the official RPC sends no
// CORS headers). Uses the Status pill.
import { useEffect, useState } from 'react'
import { Status } from './status'

const RPC = 'https://lez-testnet.84.46.247.92.sslip.io'

export function NetworkStatus({ className }: { className?: string }) {
  const [block, setBlock] = useState<number | null>(null)
  const [down, setDown] = useState(false)

  useEffect(() => {
    let live = true
    const poll = async () => {
      try {
        const r = await fetch(RPC, {
          method: 'POST',
          headers: { 'content-type': 'application/json' },
          body: JSON.stringify({ jsonrpc: '2.0', id: 1, method: 'getLastBlockId', params: [] }),
        })
        const j = await r.json()
        if (live && typeof j.result === 'number') {
          setBlock(j.result)
          setDown(false)
        }
      } catch {
        if (live) setDown(true)
      }
    }
    poll()
    const t = setInterval(poll, 10_000)
    return () => {
      live = false
      clearInterval(t)
    }
  }, [])

  if (down)
    return (
      <Status variant="warn" className={className}>
        Testnet unreachable
      </Status>
    )
  return (
    <Status variant="ok" pulse className={className}>
      LEZ 0.3 testnet{block !== null ? ` · block ${block.toLocaleString('en-US')}` : ''}
    </Status>
  )
}
