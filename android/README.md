# Armenus for Android

Render restaurant dishes in 3D and place them on a real table in AR. Kotlin.
**No WebView.**

|             | Inline preview              | AR placement        |
| ----------- | --------------------------- | ------------------- |
| **Android** | Filament via SceneView, GLB | Scene Viewer intent |

## Install

From JitPack, built from the public SDK repository:

```kotlin
// settings.gradle.kts
dependencyResolutionManagement {
  repositories {
    google()
    mavenCentral()
    maven("https://jitpack.io")
  }
}

// app/build.gradle.kts
dependencies {
  implementation("com.github.armenusapp:sdk:v0.1.0")
}
```

Android 7.0 (API 24) and later, which is what Scene Viewer requires. The
library adds **no permissions** to your manifest.

## Use

```kotlin
val armenus = ArmenusClient(publishableKey = "pk_live_...")

// In a coroutine
val item = armenus.itemByRef(merchantId, "SKU-1234")
```

A View:

```kotlin
val view = ArmenusModelView(context)
view.arLabel = "See it on your table"
view.display(item)
```

Jetpack Compose:

```kotlin
AndroidView(
  factory = { ArmenusModelView(it).apply { arLabel = "See it on your table" } },
  update = { it.display(item) },
)
```

Inside a `RecyclerView` or `LazyColumn`, set `interactionEnabled = false` so
vertical drags reach the list instead of rotating the dish, and call
`display(item)` from the binder: the view releases its renderer when detached.

## Keys

Publishable keys (`pk_...`) are **public by construction**: they ship in your
APK and anyone can read them out. That is fine. They are read-only, scoped to
your merchants, rate-limited and revocable, and they return only what the QR
menu already serves to any passer-by. Never ship a secret `ak_` key. The
client's constructor throws if you try, because it would otherwise work.

## API

| Method                                        | Returns                                                                            |
| --------------------------------------------- | ---------------------------------------------------------------------------------- |
| `config()`                                    | What this key can see. Call once at startup so a revoked key fails loudly.         |
| `item(id)`                                    | One dish, by Armenus id.                                                           |
| `itemByRef(merchantId, ref)`                  | One dish, by **your** identifier, so you never store ours.                         |
| `items(merchantId, withModel, limit, offset)` | Every dish on a merchant. `withModel = true` filters to dishes with a ready model. |
| `itemsByIds(ids)`                             | Up to 50 dishes in one request.                                                    |

All methods are `suspend` functions. Failures throw `ArmenusException`, which
carries `status`, `code`, `isRetryable` and `isAuthError`. Retryable failures
are retried with jittered backoff before you see them.

## `resolvePresentation`

The one piece of logic every Armenus SDK shares. Given a platform and a model,
it returns what to render and whether AR can be offered. On Android the
inline preview never depends on AR support: a handset without ARCore still
gets a model it can spin, which is most of the value. Probe AR with
`ArmenusAr.isAvailable(context)`; `ArmenusModelView` does this for you.

## Why no ARCore code

Scene Viewer is Google's own AR viewer, installed on every Play-services
device, and it does plane detection, real-world scale, shadows and the
placement gestures users know from Search. The SDK owns only what the system
does not give you: the inline renderer and the disk cache that feeds it.
`ArmenusAr.prefetch(context, url)` warms that cache for rows about to appear.

## Status

The library compiles and its JVM unit tests pass. It has not yet been
exercised on a physical Android device, and Scene Viewer only runs on
hardware with Google Play services. Pin an exact version until `1.0`.

## Design customization

ArmenusModelView supports native layout, arLabel, interactionEnabled and its callbacks. The built-in stage and controls use fixed internal styling; there is no shared design-token API. Compose your own surrounding dish cards and menus.

See the [cross-platform design guide](https://github.com/armenusapp/sdk/blob/main/docs/customization.md) and [developer documentation](https://developers.armenus.app).
