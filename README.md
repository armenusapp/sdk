# Armenus SDKs

Show restaurant dishes in 3D, and let guests place them on their own table in
AR, from a website or an app. One publishable key, one API, native rendering
on every platform. **No WebView anywhere.**

This repository is generated from the Armenus monorepo and is read-only; it
is where the packages are installed from and where their source can be read.
Documentation lives at [armenus.app/docs](https://armenus.app/docs).

| Platform         | Package                           | Install                                                                   | Renders with                    |
| ---------------- | --------------------------------- | ------------------------------------------------------------------------- | ------------------------------- |
| iOS (Swift)      | `Armenus` ([swift/](./swift))     | Swift Package Manager: `https://github.com/armenusapp/sdk`                | SceneKit, AR Quick Look         |
| Android (Kotlin) | `armenus` ([android/](./android)) | JitPack: `com.github.armenusapp:sdk:<tag>`                                | Filament, Scene Viewer          |
| React (web)      | `@armenus/sdk-react`              | `npm install @armenus/sdk-react`                                          | `<model-viewer>`                |
| JavaScript       | `@armenus/sdk-core`               | `npm install @armenus/sdk-core`                                           | Bring your own `<model-viewer>` |
| React Native     | `@armenus/sdk-react-native`       | `npm install @armenus/sdk-react-native@experimental`                      | SceneKit / Filament             |
| Flutter          | `armenus` ([flutter/](./flutter)) | Git dependency: `url: https://github.com/armenusapp/sdk`, `path: flutter` | SceneKit / Filament             |

Releases are tagged `v<version>`; every package in a tag shares that version.

## Getting a key

Restaurant owners create publishable keys in the dashboard under
**Settings → Embedding**. Partner platforms mint them through the partner
API. Keys start with `pk_` and are public by construction: read-only, scoped,
rate-limited and revocable. Never ship a secret `ak_` key in an app; every
SDK refuses one at construction.

## The one rule every SDK shares

There is no cross-platform model format. Apple's viewers read USDZ and
cannot read GLB; Google's read GLB and cannot read USDZ. Every model is
therefore stored as both, and the USDZ is produced after upload. On iOS a
model whose USDZ is not ready yet has **nothing to render at all**, so the
preview shows the poster image, not only a missing AR button.
`resolvePresentation()` decides this identically in every SDK.

## Status

| SDK                   | State                                                                        |
| --------------------- | ---------------------------------------------------------------------------- |
| Swift                 | Core builds and tests on macOS; iOS module compiles. Device testing pending. |
| Android               | Library compiles; JVM unit tests pass. Device testing pending.               |
| React and JavaScript  | Built and tested in the monorepo workspace.                                  |
| React Native, Flutter | Complete sources, not yet compiled against a device toolchain.               |

## Examples

[`examples/`](./examples) holds a runnable project for each web and
cross-platform SDK. Each one does the same three things: call `config()`
first, list dishes with `withModel: true` showing poster images in the grid,
and render one dish with the SDK's model component.

## License

MIT. See [LICENSE](./LICENSE).
