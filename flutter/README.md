# armenus (Flutter)

Render restaurant dishes in 3D and place them on a real table in AR. **No WebView.**

|             | Inline preview                                  | AR placement                          |
| ----------- | ----------------------------------------------- | ------------------------------------- |
| **iOS**     | SceneKit (`SCNView`) via `UiKitView`, USDZ      | AR Quick Look (`QLPreviewController`) |
| **Android** | Filament via SceneView, hybrid composition, GLB | Scene Viewer intent                   |

```yaml
dependencies:
  armenus:
    git:
      url: https://github.com/armenusapp/sdk.git
      path: flutter
      ref: main # pin to the release tag you use
```

```dart
final armenus = ArmenusClient(publishableKey: 'pk_...');
final config = await armenus.config();
if (config.merchants.isEmpty) return;
final restaurant = config.merchants.first;
final dishes = await armenus.items(restaurant.id, withModel: true);
if (dishes.isEmpty) return;
final item = dishes.first;

ArmenusModel(
  item: item,
  arLabel: 'See it on your table',
  interactionEnabled: false, // inside a ListView
);
```

`restaurant.id` is the Armenus restaurant ID returned by `config()`.
`item.id` identifies a dish in that restaurant. If you already assigned your own
catalogue reference to a dish, you can look it up with
`itemByRef(restaurant.id, yourReference)` instead.

## Native project setup

Use Android API 24 or later (`minSdk = 24` in the app’s Gradle configuration),
Java 17 and Kotlin 2.0.21 or later. On iOS, the plugin supports iOS 13 or later
and integrates through CocoaPods. Run `flutter pub get`, then rebuild your app
so Flutter registers the native plugin.

## How AR opens

On iOS, the SDK opens Apple's built-in Quick Look viewer with the dish's USDZ
file. On Android, it opens Google's Scene Viewer with the GLB file. These viewers
handle placing the dish on a surface. The SDK also provides the 3D preview inside
your app and a download cache.

## Permissions

Android declares the normal `INTERNET` permission to download menu data and model files; it does not show a permission prompt. The SDK does not request camera access. AR opens in the system viewer.

## Notes

- **Hybrid composition on Android** (`PlatformViewLink` + `AndroidViewSurface`), which is what lets the Filament surface composite correctly with Flutter widgets drawn above it — the AR button sits on top of the canvas, and virtual-display mode gets that wrong.
- **`interactionEnabled: false` inside a scrollable.** The platform view and Flutter's scrollable otherwise fight over the gesture arena.
- **`ArmenusAr.prefetch(url)`** downloads a model before it is opened. This is optional; the viewer downloads it when needed.
- **On iOS a missing USDZ blanks the preview**, not just the AR button: SceneKit cannot open a GLB. `resolvePresentation()` decides what to render; do not reach for `model.glbUrl` on iOS yourself. `Presentation.blockedOnConversion` distinguishes "still being made" from genuinely unavailable.

## Run the SDK checks

From the Flutter package directory:

```sh
flutter pub get
flutter analyze
flutter test
```

The repository's `examples/flutter` app includes a native integration test.
Generate its native projects with `flutter create --platforms=android,ios .`,
then run `flutter test integration_test/native_smoke_test.dart -d <device-id>`.
The test checks model downloads, cache reuse, native rendering and switching dishes.

## Design customization

ArmenusModel exposes arLabel, interactionEnabled, aspectRatio, onEnterAr and onError. Compose your layout around the widget. A comprehensive palette, typography and slot API is not currently exposed; do not assume ThemeData changes every internal color.

See the [cross-platform design guide](https://github.com/armenusapp/sdk/blob/main/docs/customization.md) and [developer documentation](https://developers.armenus.app).
