# @armenus/sdk-core

Framework-agnostic client for the Armenus embed API. **Zero runtime dependencies.**

npm publication is pending. Obtain the matching versioned integration archives.
See the [installation guide](https://github.com/armenusapp/sdk/blob/main/docs/getting-started.md).

Most people want [`@armenus/sdk-react`](../sdk-react) (web), [`@armenus/sdk-react-native`](../sdk-react-native), or the [Flutter package](../sdk-flutter). Use this directly for Vue, Svelte, plain JS, or a server-side render.

```ts
import { ArmenusClient } from "@armenus/sdk-core";

const armenus = new ArmenusClient({ publishableKey: "pk_..." });

const config = await armenus.config();
// A "merchant" is a restaurant. Choose one this key can access.
const restaurant = config.merchants[0];
if (restaurant) {
  const result = await armenus.items(restaurant.id, { withModel: true });
  const item = result.items[0];
  if (item) console.log(item.model?.glbUrl, item.model?.usdzUrl);
}
```

## Keys

Publishable keys (`pk_...`) are **public by construction** — they ship in your bundle and anyone can read them out. That is fine: they are read-only, scoped to your merchants, quota-limited per key, revocable, and return only the data the QR menu already serves anonymously to any passer-by.

Never ship a secret `ak_` key in client code. The constructor throws if you try, because it would otherwise work — all the way into production.

## API

| Method                       | Returns                                                                                                                                   |
| ---------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| `config()`                   | What this key can see. Call once at startup so a revoked key fails loudly instead of presenting as an empty catalogue.                    |
| `item(id)`                   | One dish, by Armenus id.                                                                                                                  |
| `itemByRef(merchantId, ref)` | One dish, by **your** identifier — so you never store ours.                                                                               |
| `items(merchantId, opts)`    | Every dish on a merchant. `withModel: true` filters to dishes with a ready, published model, and paginates correctly against that filter. |
| `itemsByIds(ids)`            | Up to 50 dishes in one request. A grid needs twenty models at once.                                                                       |

All methods take an optional `AbortSignal`. Failures throw `ArmenusError`, which carries `status`, `code`, `isRetryable` and `isAuthError` — you will branch on those far more than you read the message.

## `resolvePresentation()`

The one piece of logic every SDK needs and none should own. Given a platform and a model, it returns what to render and whether AR can be offered.

The rules are not symmetric and getting them wrong yields a blank canvas with no error:

- **There is no cross-platform AR API.** WebXR, Scene Viewer and AR Quick Look are mutually exclusive; a device supports at most one.
- **There is no cross-platform model format.** Quick Look and SceneKit read USDZ and cannot read glTF. Scene Viewer and Filament read GLB and cannot read USDZ. Every model is therefore stored as both, and the USDZ is produced asynchronously after upload.
- **The consequence people miss:** on native iOS a missing USDZ costs the _inline preview_ too, not just the AR button. There is nothing an iPhone can draw, so it falls back to the poster image.

```ts
const { inline, ar } = resolvePresentation({
  platform: "ios",
  model: item.model,
});
// inline.kind: "glb" | "usdz" | "poster" | "none"
// ar.blockedOnConversion: true when the USDZ is merely still being made
```

`ar.blockedOnConversion` is separated from every other unsupported case because it is the one where "check back shortly" is honest rather than a permanent-looking failure.

## React

React bindings live at `@armenus/sdk-core/react` — a separate entry point so the zero-dependency promise of the main entry stays true. React is an optional peer and is never resolved by a non-React consumer.

## Design and integration documentation

See [developer documentation](https://developers.armenus.app), the
[design guide](https://github.com/armenusapp/sdk/blob/main/docs/customization.md), and
[troubleshooting](https://github.com/armenusapp/sdk/blob/main/docs/troubleshooting.md).

The core client is headless: build your own design in React, Vue, Svelte or plain
JavaScript. `baseUrl`, `timeoutMs`, `retries` and `fetch` configure requests.
`retries` counts all attempts including the first. Call `config()` before listing
items, handle `ArmenusError`, and use `resolvePresentation` for rendering and AR
fallbacks. Browser inline GLB works on iPhone; native iOS requires USDZ.
