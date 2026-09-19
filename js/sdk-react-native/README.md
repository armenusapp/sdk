# @armenus/sdk-react-native

Native 3D and AR dish rendering for React Native. **No WebView.**

|             | Inline preview              | AR placement                          |
| ----------- | --------------------------- | ------------------------------------- |
| **iOS**     | SceneKit (`SCNView`), USDZ  | AR Quick Look (`QLPreviewController`) |
| **Android** | Filament via SceneView, GLB | Scene Viewer intent                   |

npm publication is pending. Obtain the matching versioned integration archives.
See the [installation guide](https://github.com/armenusapp/sdk/blob/main/docs/getting-started.md).

Android: add `ArmenusPackage()` to your `MainApplication` package list.

```tsx
import {
  ArmenusProvider,
  ArmenusModel,
  useArmenusItem,
} from "@armenus/sdk-react-native";

export function Dish({ itemId }: { itemId: string }) {
  const { data } = useArmenusItem(itemId);
  return <ArmenusModel item={data} interactionEnabled={false} />;
}
```

## Why no ARKit or ARCore rendering code

Because neither platform needs it, and writing it would land somewhere worse.

`QLPreviewController` in AR mode **is ARKit** — plane detection, real-world scale, people occlusion, contact shadows, and the drag/rotate/scale gestures every iPhone user already knows from Safari and Messages. It is about thirty lines to present. Scene Viewer is the same story on ARCore, launched by an intent.

Hand-rolling an `ARSCNView` equivalent means reimplementing all of that, diverging from the AR interaction users have seen everywhere else, and maintaining it per platform forever.

What the native code here _does_ own is the part the system does not give you: a renderer for the inline preview, and the disk cache that feeds both paths.

## Permissions

**This SDK adds none.** Placement runs in the system AR viewer, a separate app that holds the camera permission itself. Your Play Store data-safety declaration and your iOS privacy manifest are unchanged by installing this.

## Performance

- **Prefetch.** `ArmenusModel` warms the cache as soon as it knows AR is offerable. Quick Look cannot read a remote URL, so the download happens either way — only its timing is yours to choose, and choosing early is the difference between an AR button that opens instantly and one that stalls for two seconds while the user wonders whether the tap registered. Call `ArmenusNative.prefetch(url)` yourself for rows about to scroll into view.
- **Parsing is off the main thread** on both platforms. A textured dish is a few MB, and decoding it inline drops frames in whatever list the card is sitting in.
- **Renderers pause when off screen.** Each `SCNView` owns a `CADisplayLink`; a feed with twenty cards all rendering off screen drains the battery and drops the scroll below 60fps for nothing visible. Android drives rotation from `Choreographer`, so it is tied to actual frame delivery rather than a timer that keeps firing while throttled.
- **`interactionEnabled={false}` inside a `FlatList`.** On a phone the two gesture systems fight, and a card that swallows vertical drags makes the whole feed feel stuck.
- **LRU disk cache**, 256 MB, in the OS cache directory — so it is evictable under storage pressure and never counts against the user's backup quota.

## The iOS gate worth knowing about

SceneKit cannot open a GLB. So on iOS, a model whose USDZ conversion has not finished has **nothing to render at all** — not just a missing AR button, but a preview that falls back to the poster image. `resolvePresentation()` decides this; never reach for `model.glbUrl` on iOS yourself.

`presentation.ar.blockedOnConversion` tells you the difference between "still being made" (resolves in a minute or two) and genuinely unavailable.

## Status

The TypeScript side builds and type-checks in the Armenus workspace. The Swift and Kotlin sources are complete but have **not been compiled or run** against a React Native toolchain, and the planned npm release uses the `experimental` tag rather than `latest`. Pin the exact version, and expect device validation before `1.0`.

## Design and integration documentation

See [developer documentation](https://developers.armenus.app), the
[design guide](https://github.com/armenusapp/sdk/blob/main/docs/customization.md), and
[troubleshooting](https://github.com/armenusapp/sdk/blob/main/docs/troubleshooting.md).

The component exposes outer `style`, `arLabel`, `interactionEnabled`, `footer`,
`onEnterAr` and `onError`. The internal stage, button and note currently use fixed
styles. Outer `style` does not theme those elements. A universal native theme
object is not part of the API. Run CocoaPods for iOS in a native development build;
this native module is not available in a stock Expo Go runtime.
