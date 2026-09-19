# Integrate Armenus

Armenus SDKs provide read-only menu data and individual 3D/AR dish viewers.
Your application owns the surrounding design, navigation, pricing display and
selection or checkout workflow. The SDK does not submit restaurant orders.

## 1. Choose a platform and installation method

| Platform           | Installation                                                                                     | Validation boundary                                                |
| ------------------ | ------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------ |
| JavaScript / React | Obtain the matching `0.1.0` integration package archives. npm publication is pending.            | Build and type checks run in the workspace.                        |
| React Native       | Obtain the core and React Native archives; install native dependencies in a native build.        | Experimental; native device-toolchain validation is pending.       |
| Flutter            | Git dependency on `https://github.com/armenusapp/sdk`, `path: flutter`, pinned to a release tag. | Experimental; native device-toolchain validation is pending.       |
| Swift              | Swift Package Manager, `https://github.com/armenusapp/sdk`, product `Armenus`.                   | iOS module compilation verified; device testing is still required. |
| Android            | JitPack, `com.github.armenusapp:sdk:<tag>`.                                                      | Library and JVM tests verified; device testing is still required.  |

Do not assume an npm install succeeds until the package is actually published.
The `js/` folders contain source, not built npm distributions. Installing this
repository root as an npm package is not a substitute for the package archives.
See each platform README for setup and minimum versions.

For supplied web archives in an existing React project:

```sh
npm install ./armenus-sdk-core-0.1.0.tgz ./armenus-sdk-react-0.1.0.tgz
```

Keep both archives on the same version. React and React DOM are peer dependencies.

## 2. Create a publishable key

The restaurant owner opens **Settings → Embedding** in the dashboard and creates
a `pk_` key. Restrict origins if required, including the actual local development
origin. Publishable keys are visible to app users by design, read-only, scoped
and revocable. Keep partner `ak_` keys on a trusted server; SDK constructors reject
them. An origin allowlist is not a secret-key replacement for a native client.

## 3. Check access before rendering

```ts
import { ArmenusClient } from "@armenus/sdk-core";

const client = new ArmenusClient({
  publishableKey: "pk_your_key",
  baseUrl: "https://api.armenus.app/v1",
  timeoutMs: 8000,
  retries: 2,
});

const config = await client.config();
// Select a merchant ID available to this key from config.merchants.
const merchant = config.merchants[0];
if (!merchant) throw new Error("This key has no merchants");
const result = await client.items(merchant.id, { withModel: true, limit: 20 });
console.log(result.items);
```

`retries` is the total number of attempts, including the first; `1` disables
retries. Pass an AbortSignal to client calls when your screen or request ends.

## 4. Render a dish in React

```tsx
"use client";
import { ArmenusProvider, ArmenusModel, useArmenusItem } from "@armenus/sdk-react";
import "@armenus/sdk-react/styles.css";

function Dish({ id }: { id: string }) {
  const { data, loading, error } = useArmenusItem(id);
  if (error) return <p>{error.message}</p>;
  if (loading) return <p>Loading dish…</p>;
  return <ArmenusModel item={data} arLabel="See it on your table" />;
}

export function DishScreen({ itemId }: { itemId: string }) {
  return (
    <ArmenusProvider publishableKey="pk_your_key">
      <Dish id={itemId} />
    </ArmenusProvider>
  );
}
```

In Next.js, use a client component for the provider, hooks and viewer. Import
styles in a location permitted by your app's CSS setup. The model engine loads
in the browser after mount. Use poster images in grids and mount the interactive
viewer where the guest chooses a dish.

## 5. Test publication, fallback and devices

Check an active and revoked key, a scoped-out item, an item with no model, a
model whose USDZ is still converting, and a failed network request. If the
restaurant uses review publishing, verify a published revision exists.

Browser inline 3D renders GLB, including on iPhone. **Native iOS** previews and
iOS AR need USDZ; a missing USDZ requires a poster fallback. Android native uses
GLB. Test AR on a supported physical phone over HTTPS where applicable. Desktop
3D success is not proof that AR works.

Next: [Customize the design](./customization.md) ·
[Troubleshooting](./troubleshooting.md) ·
[Full API reference](https://developers.armenus.app/client)
