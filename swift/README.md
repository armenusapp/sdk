# Armenus for iOS

Show a restaurant's dishes as interactive 3D models in your iOS app. Guests can
also open a model in Apple's AR viewer to see it on their table.

Requires iOS 15 or later. Use SwiftUI or UIKit.

## Install

In Xcode, choose **File → Add Package Dependencies**, enter
`https://github.com/armenusapp/sdk`, and add the **Armenus** product to your app.
For a `Package.swift` manifest:

```swift
.package(url: "https://github.com/armenusapp/sdk.git", exact: "0.1.0")
```

Use the `ArmenusCore` product instead if you only need menu data, without a viewer.

## Get your restaurant and its dishes

First, the restaurant owner creates a publishable key in **Settings → Embedding**
in the Armenus dashboard. Replace `pk_your_key` below with that key.

The API calls a restaurant a **merchant**. You get the restaurant's ID from
`client.config()`; you do not have to guess it or copy an ID from a URL.

```swift
import Armenus

// Call from an async function or a Task in your app.
func loadFirstDish(publishableKey: String) async throws -> EmbedItem? {
  let client = try ArmenusClient(publishableKey: publishableKey)
  let config = try await client.config()

  // config.merchants lists the restaurants this key can access.
  // Each has an id, name and slug. This example uses the first restaurant.
  guard let restaurant = config.merchants.first else {
    return nil // The key has no accessible restaurants.
  }

  let result = try await client.items(
    merchantID: restaurant.id,
    withModel: true, // Only dishes with an available model.
    limit: 20
  )
  return result.items.first // nil when no matching dishes are available.
}
```

Call `try await loadFirstDish(publishableKey: "pk_your_key")` from your screen's
async loading code. Handle a thrown error and the case where it returns `nil`.
For a key that can access several restaurants, show a restaurant picker using
`config.merchants` and pass the selected restaurant's `id` to `items(merchantID:)`.

## What the IDs mean

| Name | Meaning | Where it comes from |
| --- | --- | --- |
| `merchantID` | The restaurant's Armenus ID | `config.merchants`, or `item.merchant.id` |
| `itemID` | A dish's Armenus ID | `result.items`, using each dish's `id` |
| `externalRef` | An optional product ID from your own catalogue, such as a POS SKU | A reference already assigned to that dish by your integration |

The restaurant ID is not your API key or your restaurant's URL slug.
You do **not** need an `externalRef` for a normal integration: list dishes and use
their Armenus IDs. Once you have a dish, `try await client.item(item.id)` fetches
that same dish again.

`item(merchantID:externalRef:)` is an alternative for integrations that have
already assigned their own product IDs to Armenus dishes. It does not create
that mapping. `"SKU-1234"` in older examples was only a placeholder; it is not a
built-in demo dish and will not work unless your data contains that reference.

## Display the dish

Pass the `EmbedItem` you loaded to a SwiftUI view:

```swift
import Armenus
import SwiftUI

struct DishView: View {
  let item: EmbedItem

  var body: some View {
    ArmenusModel(item: item, arLabel: "See it on your table")
  }
}
```

Or, inside your UIKit screen after loading `item`:

```swift
let viewer = ArmenusModelView()
viewer.arLabel = "See it on your table"
viewer.accentColor = .systemGreen
viewer.display(item)
// Add viewer to your view hierarchy and give it layout constraints.
```

Set `interactionEnabled` to `false` inside a scrolling list if dragging the model
prevents the list from scrolling. Your app owns the surrounding layout.

## What happens when a guest uses AR?

The model first appears inside your app, where the guest can rotate it.
When they tap the AR button, Armenus opens Apple's **Quick Look** viewer.
On a supported device, that viewer lets them see the dish on a real table through
the camera. You do not need to build that AR screen yourself.

The SDK downloads the model file and saves a local copy for the viewer to use.
`ArmenusAR.prefetch(url)` optionally starts that download earlier, before the
guest taps the button. That can reduce waiting; it does not guarantee an instant
load. The built-in model view handles its normal downloads, so prefetching is
not required to get started.

Quick Look is Apple's ready-made viewer. ARKit is Apple's framework for building
custom AR experiences. Calling them the same thing was misleading. The SDK
presents Quick Look rather than implementing a custom AR session.
See [Apple's Quick Look overview](https://developer.apple.com/quick-look-gallery/).

## Model formats and fallback

The native iOS viewer uses **USDZ**, Apple's supported model format. Armenus
prepares that file separately from the **GLB** used on the web and Android.
If USDZ is not ready, the native iOS viewer shows a poster image instead.

`resolvePresentation(platform:model:)` reports which file or fallback to show
and whether AR is available. The built-in viewers use it for you.
`presentation.ar.blockedOnConversion` means the iOS file is still being prepared.

## Client reference

| Method | Result |
| --- | --- |
| `config()` | Restaurants and access available to the publishable key |
| `items(merchantID:withModel:limit:offset:)` | A page of dishes from the chosen restaurant |
| `item(_:)` | One dish by its Armenus ID |
| `item(merchantID:externalRef:)` | One dish by an existing external reference within that restaurant |
| `items(ids:)` | Up to 50 dishes by their Armenus IDs |

Methods are `async throws`. Failures use `ArmenusError`, with `status`, `code`,
`isRetryable` and `isAuthError`. The client retries eligible failures before
returning an error. Optional settings are `baseURL`, `timeout` in seconds,
`retries` as total attempts, and an injected `URLSession`.

Publishable `pk_` keys are read-only and intended for client apps. Keep secret
`ak_` keys on your server; the client rejects them.

## Design controls

SwiftUI `ArmenusModel` exposes `arLabel`, `interactionEnabled`, `onEnterAR` and
`onError`. UIKit `ArmenusModelView` also exposes `accentColor` for the AR button;
the SwiftUI wrapper does not currently forward that property. These controls
are not a complete theme system and do not restyle Apple's AR screen.

## Validation status

The core module builds and its tests pass on macOS; the iOS module compiles for
the simulator. Physical iPhone rendering and AR testing are still required.
Pin a release version while integrating.

[Complete iOS / Swift guide](https://developers.armenus.app/swift) ·
[Design guide](https://github.com/armenusapp/sdk/blob/main/docs/customization.md)
