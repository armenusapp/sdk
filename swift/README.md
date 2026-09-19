# Armenus for iOS

Render restaurant dishes in 3D and place them on a real table in AR. Swift,
UIKit and SwiftUI. **No WebView.**

|         | Inline preview             | AR placement                          |
| ------- | -------------------------- | ------------------------------------- |
| **iOS** | SceneKit (`SCNView`), USDZ | AR Quick Look (`QLPreviewController`) |

## Install

Swift Package Manager, from the public SDK repository:

```
https://github.com/armenusapp/sdk
```

In Xcode: File → Add Package Dependencies, paste the URL, pick the `Armenus`
product. Or in `Package.swift`:

```swift
.package(url: "https://github.com/armenusapp/sdk.git", from: "0.1.0")
```

iOS 15 and later. `ArmenusCore` is also available on its own for code that
only needs the client and the presentation rules, including on macOS.

## Use

```swift
import Armenus

let armenus = try ArmenusClient(publishableKey: "pk_live_...")
let item = try await armenus.item(merchantID: merchantID, externalRef: "SKU-1234")
```

SwiftUI:

```swift
ArmenusModel(item: item, arLabel: "See it on your table")
  // Inside a List or ScrollView row:
  // ArmenusModel(item: item, interactionEnabled: false)
```

UIKit:

```swift
let view = ArmenusModelView()
view.arLabel = "See it on your table"
view.display(item)
```

## Keys

Publishable keys (`pk_...`) are **public by construction**: they ship in your
app and anyone can read them out. That is fine. They are read-only, scoped to
your merchants, rate-limited and revocable, and they return only what the QR
menu already serves to any passer-by. Never ship a secret `ak_` key. The
client's initialiser throws if you try, because it would otherwise work.

## API

| Method                                      | Returns                                                                           |
| ------------------------------------------- | --------------------------------------------------------------------------------- |
| `config()`                                  | What this key can see. Call once at startup so a revoked key fails loudly.        |
| `item(_:)`                                  | One dish, by Armenus id.                                                          |
| `item(merchantID:externalRef:)`             | One dish, by **your** identifier, so you never store ours.                        |
| `items(merchantID:withModel:limit:offset:)` | Every dish on a merchant. `withModel: true` filters to dishes with a ready model. |
| `items(ids:)`                               | Up to 50 dishes in one request.                                                   |

Failures throw `ArmenusError`, which carries `status`, `code`, `isRetryable` and
`isAuthError`. Retryable failures are retried with jittered backoff before you
see them.

## `resolvePresentation`

The one piece of logic every Armenus SDK shares. Given a platform and a model,
it returns what to render and whether AR can be offered. The rule that catches
people out on iOS: **a model whose USDZ conversion has not finished has nothing
to render at all**, not just a missing AR button. SceneKit cannot open a GLB,
so the preview falls back to the poster image. `presentation.ar.blockedOnConversion`
tells "still being made" apart from genuinely unavailable.

`ArmenusModelView` never second-guesses this function. What it draws is what
the function returned.

## Why no ARKit code

`QLPreviewController` in AR mode _is_ ARKit: plane detection, real-world
scale, people occlusion, contact shadows and the gestures every iPhone user
already knows from Safari and Messages. The SDK owns only what the system
does not give you: the inline renderer and the disk cache that feeds both
paths. `ArmenusAR.prefetch(_:)` warms that cache for rows about to appear,
because Quick Look cannot read a remote URL and the download happens either
way; only its timing is yours.

## Permissions

None added. Placement runs in the system AR viewer, which holds the camera
permission in its own process.

## Status

The core module builds and its tests pass on macOS; the iOS module compiles
for the simulator. It has not yet been exercised on a physical iPhone, and AR
Quick Look only runs on hardware. Pin an exact version until `1.0`.

## Design customization

The SwiftUI ArmenusModel exposes arLabel, interactionEnabled, onEnterAR and onError. Use SwiftUI layout modifiers around the viewer. Its UIKit internals do not expose a complete theme object; surrounding layout and model framing are separate from internal button styling.

See the [cross-platform design guide](https://github.com/armenusapp/sdk/blob/main/docs/customization.md) and [developer documentation](https://developers.armenus.app).

UIKit ArmenusModelView exposes accentColor for the AR button; the SwiftUI wrapper does not forward it. The client accepts baseURL, timeout in seconds, retries and an injected URLSession.

[Complete iOS / Swift setup guide](https://developers.armenus.app/swift).
