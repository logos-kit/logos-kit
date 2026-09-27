export function installQmlHost(host: {
  setTimeout(fn: () => void, ms: number): unknown
  clearTimeout(id: unknown): void
  randomBytes?(n: number): ArrayLike<number>
}): void
