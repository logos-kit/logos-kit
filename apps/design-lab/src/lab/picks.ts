import { useCallback, useEffect, useRef, useState } from 'react'

// Picks are saved to the artifact's db (read back by Claude); outside the
// artifact viewer they fall back to this browser only.
type Pick = { option: string | null; note: string; updatedAt?: string }
type Db = {
  doc: (p: string) => { set: (d: Record<string, unknown>) => Promise<void> }
  collection: (p: string) => {
    get: () => Promise<{
      docs: { id: string; exists: boolean; data: () => Record<string, unknown> | undefined }[]
    }>
  }
}
declare global {
  interface Window {
    claude?: { use?: (name: string) => Promise<unknown> }
  }
}

export function usePicks() {
  const [picks, setPicks] = useState<Record<string, Pick>>(() => {
    try {
      return JSON.parse(localStorage.getItem('lk-lab-picks') || '{}')
    } catch {
      return {}
    }
  })
  const [store, setStore] = useState<'connecting' | 'page' | 'local'>('connecting')
  const [saved, setSaved] = useState<Record<string, string>>({})
  const db = useRef<Db | null>(null)
  const timers = useRef<Record<string, number>>({})

  useEffect(() => {
    const use = window.claude?.use
    if (!use) {
      setStore('local')
      return
    }
    use('db')
      .then(async (handle) => {
        if (!handle) return setStore('local')
        db.current = handle as Db
        setStore('page')
        const snap = await db.current.collection('picks').get()
        const loaded: Record<string, Pick> = {}
        for (const d of snap.docs) if (d.exists) loaded[d.id] = d.data() as Pick
        setPicks((p) => ({ ...p, ...loaded }))
      })
      .catch(() => setStore('local'))
  }, [])

  const persist = useCallback((id: string, next: Pick) => {
    try {
      const all = JSON.parse(localStorage.getItem('lk-lab-picks') || '{}')
      all[id] = next
      localStorage.setItem('lk-lab-picks', JSON.stringify(all))
    } catch {}
    if (!db.current) {
      setSaved((s) => ({ ...s, [id]: 'Saved here' }))
      return
    }
    setSaved((s) => ({ ...s, [id]: 'Saving…' }))
    db.current
      .doc(`picks/${id}`)
      .set({ ...next, updatedAt: new Date().toISOString() })
      .then(
        () => setSaved((s) => ({ ...s, [id]: 'Saved' })),
        () => setSaved((s) => ({ ...s, [id]: 'Not saved' })),
      )
  }, [])

  const choose = useCallback(
    (id: string, option: string) => {
      setPicks((p) => {
        const next = { option, note: p[id]?.note ?? '' }
        persist(id, next)
        return { ...p, [id]: next }
      })
    },
    [persist],
  )

  const note = useCallback(
    (id: string, text: string) => {
      setPicks((p) => {
        const next = { option: p[id]?.option ?? null, note: text }
        window.clearTimeout(timers.current[id])
        timers.current[id] = window.setTimeout(() => persist(id, next), 700)
        return { ...p, [id]: next }
      })
    },
    [persist],
  )

  return { picks, store, saved, choose, note }
}
