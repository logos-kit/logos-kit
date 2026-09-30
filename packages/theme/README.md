# @logos-kit/theme

The Logos Kit design tokens: the **Tray** theme in light and dark, used by the wallet, its Basecamp apps and the docs. One source of truth, exported for CSS and for QML.

```sh
pnpm add @logos-kit/theme
```

```ts
import { cssVars, themes, toQmlTokens } from '@logos-kit/theme'

// CSS custom properties for the dark theme
const vars = cssVars(themes.dark)

// The same tokens for a QML app (colours in Qt's #AARRGGBB form)
const qml = toQmlTokens(themes.dark)
```

## Links

- Docs: [UI kit](https://logos-kit-docs.vercel.app/docs/sdk/ui)
- Source: [logos-kit/logos-kit](https://github.com/logos-kit/logos-kit/tree/main/packages/theme)

## License

MIT OR Apache-2.0
