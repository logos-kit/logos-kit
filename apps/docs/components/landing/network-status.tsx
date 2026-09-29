'use client'

// Live preview-network status: the sequencer's latest block, read from the
// browser (the preview RPC sends CORS headers). Uses the Status pill.
import { useEffect, useState } from 'react'
import { Status } from './status'

const RPC = 'https://lez.84.46.247.92.sslip.io'

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
        Preview network unreachable
      </Status>
    )
  return (
    <Status variant="ok" pulse className={className}>
      LEZ 0.3 preview network{block !== null ? ` · block ${block.toLocaleString('en-US')}` : ''}
    </Status>
  )
}
