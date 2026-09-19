# Examples

Runnable projects for the web and cross-platform SDKs. Follow each example’s
README to install its SDK dependency, generate native projects where needed,
and configure a publishable key. Native Swift and Kotlin setup examples are in
their [platform guides](https://developers.armenus.app).

| Example                          | Stack                   | Renders with        |
| -------------------------------- | ----------------------- | ------------------- |
| [`react-web`](./react-web)       | Vite + React            | `<model-viewer>`    |
| [`react-native`](./react-native) | Expo dev build          | SceneKit / Filament |
| [`flutter`](./flutter)           | Flutter                 | SceneKit / Filament |
| [`vanilla-js`](./vanilla-js)     | One HTML file, no build | `<model-viewer>`    |

All four do the same three things, so they are worth reading side by side:

1. Call `config()` before anything else — the only way to tell a revoked key
   apart from an empty menu.
2. List dishes with `withModel: true`, showing **poster images** in the grid
   rather than a renderer per cell.
3. Render one dish with the SDK's model component, which handles device
   capability, format selection, prefetching and the AR handoff.

## Getting a key

From the dashboard under **Settings → Embedding**, or:

```bash
curl https://api.armenus.app/v1/partner/publishable-keys \
  -H "Authorization: Bearer ak_your_secret_key" \
  -H "Content-Type: application/json" \
  -d '{"label":"example app","allowedOrigins":[]}'
```

Publishable keys are safe to commit — they ship inside your bundle either way.
Never put a secret `ak_` key in an example; the SDKs throw if you try.

## Only `react-web` is in the pnpm workspace

Deliberately. It compiles against the local SDK on every build, so a broken
public API cannot ship unnoticed. The native examples stay out — they would
drag an Expo and a Flutter toolchain into `pnpm install` for everyone, and they
have their own toolchains and setup instructions.
