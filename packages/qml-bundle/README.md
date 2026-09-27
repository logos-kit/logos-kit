# @logos-kit/qml-bundle (private)

Builds the Logos Kit SDK for Basecamp QML apps into `sdk/qml/LogosKit/`:
`logoskit.js` (one ES2016 `.pragma library`, no BigInt, about 28 KB),
`Tokens.js` (Tray tokens) and the thin `LogosKit.qml` wrapper.

- `pnpm build`: the pipeline in `build.mjs` (esbuild → Qt V4 babel fix → esbuild ES2016 IIFE).
- `pnpm gate`: the **QML engine gate**. Builds `gate/suite.ts` the same way and runs it in
  Node, Qt 6.9.2 and Qt 6.11.1 (PySide6 in `.qt/`, created with uv), then diffs the logs.

`src/qml-shims.js`, `babel-plugin-qml-v4.cjs`, `gate/qmlrun.py` and `gate/noderun.cjs` are
ported unchanged from the research pipeline
(`refs/connect-kits/_notes/artifacts/qml-transpile/pipe`), where they were tested on both Qt versions.
