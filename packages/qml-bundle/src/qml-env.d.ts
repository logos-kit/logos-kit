// Globals the bundle may use inside QML. Qt's V4 has no timers; qml-shims.js
// adds them (backed by the host's QML Timer via installQmlHost).
declare function setTimeout(fn: () => void, ms?: number): unknown
declare function clearTimeout(id: unknown): void
