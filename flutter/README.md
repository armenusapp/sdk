# armenus (Flutter)

Render restaurant dishes in 3D and place them on a real table in AR. **No WebView.**

|             | Inline preview                                  | AR placement                          |
| ----------- | ----------------------------------------------- | ------------------------------------- |
| **iOS**     | SceneKit (`SCNView`) via `UiKitView`, USDZ      | AR Quick Look (`QLPreviewController`) |
| **Android** | Filament via SceneView, hybrid composition, GLB | Scene Viewer intent                   |

```yaml
dependencies:
  armenus: ^0.1.0
```

```dart
final armenus = ArmenusClient(publishableKey: 'pk_...');
final item = await armenus.itemByRef(merchantId, 'SKU-1234');

ArmenusModel(
  item: item,
  arLabel: 'See it on your table',
  interactionEnabled: false, // inside a ListView
);
```

## Why no ARKit or ARCore rendering code

`QLPreviewController` in AR mode **is ARKit** — plane detection, real-world scale, people occlusion, contact shadows, and the gestures every iPhone user already knows. Scene Viewer is the same on ARCore. Both take a file and a size. Reimplementing either means far more code arriving somewhere worse and less familiar.

The plugin's native code owns only what the system does not provide: the inline renderer and the disk cache that feeds both paths.

## Permissions

**None added.** Placement runs in the system AR viewer, which holds the camera permission in its own process.

## Notes

- **Hybrid composition on Android** (`PlatformViewLink` + `AndroidViewSurface`), which is what lets the Filament surface composite correctly with Flutter widgets drawn above it — the AR button sits on top of the canvas, and virtual-display mode gets that wrong.
- **`interactionEnabled: false` inside a scrollable.** The platform view and Flutter's scrollable otherwise fight over the gesture arena.
- **`ArmenusAr.prefetch(url)`** warms the cache for rows about to appear. Quick Look cannot read a remote URL, so the download happens regardless — only its timing is yours.
- **On iOS a missing USDZ blanks the preview**, not just the AR button: SceneKit cannot open a GLB. `resolvePresentation()` decides what to render; do not reach for `model.glbUrl` on iOS yourself. `Presentation.blockedOnConversion` distinguishes "still being made" from genuinely unavailable.

## Status

The Dart and native sources are complete, but this package has **not been compiled or run** — see the repository's SDK notes. It needs a `flutter analyze`, a build against a real Flutter toolchain, and device testing before publication.
