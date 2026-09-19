# @armenus/sdk-react-native

Native 3D and AR dish rendering for React Native. **No WebView.**

|             | Inline preview              | AR placement                          |
| ----------- | --------------------------- | ------------------------------------- |
| **iOS**     | SceneKit (`SCNView`), USDZ  | AR Quick Look (`QLPreviewController`) |
| **Android** | Filament via SceneView, GLB | Scene Viewer intent                   |

npm publication is pending. Obtain the matching versioned integration archives.
See the [installation guide](https://github.com/armenusapp/sdk/blob/main/docs/getting-started.md).

React Native autolinks the native package. Run `pod install` in your iOS project
and rebuild both native apps. Do not register `ArmenusPackage()` a second time
when Android autolinking is enabled. Android requires API 24 or later, Java 17
and Kotlin 2.0.21 or later.

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

## How the 3D and AR views work

The dish appears inside your app as a rotatable 3D model. When the guest taps
the AR button, the SDK opens Apple's Quick Look viewer on iOS or Google's Scene
Viewer on Android. Those viewers provide the interface for placing the dish in
the camera view on a supported device. Your app does not need to build that
AR interface itself.

The SDK also downloads model files and keeps local copies so the previews can
reuse them. Explicit prefetching starts a download ahead of time; it is optional.

## Permissions

Android declares the normal `INTERNET` permission to download menu data and model files; it does not show a permission prompt. The SDK does not request camera access. AR opens in the system viewer.

## Performance

- **Prefetch.** The built-in viewer handles normal model loading. You can call `ArmenusNative.prefetch(url)` to download a model ahead of an expected interaction. This can reduce waiting when the guest opens it; it does not guarantee an instant load.
- **Parsing is off the main thread** on both platforms. A textured dish is a few MB, and decoding it inline drops frames in whatever list the card is sitting in.
- **Renderers pause when off screen.** Each `SCNView` owns a `CADisplayLink`; a feed with twenty cards all rendering off screen drains the battery and drops the scroll below 60fps for nothing visible. Android drives rotation from `Choreographer`, so it is tied to actual frame delivery rather than a timer that keeps firing while throttled.
- **`interactionEnabled={false}` inside a `FlatList`.** On a phone the two gesture systems fight, and a card that swallows vertical drags makes the whole feed feel stuck.
- **LRU disk cache**, 256 MB, in the OS cache directory — so it is evictable under storage pressure and never counts against the user's backup quota.

## The iOS gate worth knowing about

SceneKit cannot open a GLB. So on iOS, a model whose USDZ conversion has not finished has **nothing to render at all** — not just a missing AR button, but a preview that falls back to the poster image. `resolvePresentation()` decides this; never reach for `model.glbUrl` on iOS yourself.

`presentation.ar.blockedOnConversion` tells you the difference between "still being made" (resolves in a minute or two) and genuinely unavailable.

## Native builds

Use a native React Native build or an Expo development build. Expo Go cannot load this package’s native modules. After installing the package, run CocoaPods for iOS and rebuild the app. The included Expo example configures Kotlin 2.0.21 for the Android renderer and pins its Gradle plugin version. In an existing Android host, set both `kotlinVersion` and the buildscript dependency `classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")`; an unversioned dependency can select an older compiler. Keep the core and React Native packages on the same version.

## Design and integration documentation

See [developer documentation](https://developers.armenus.app), the
[design guide](https://github.com/armenusapp/sdk/blob/main/docs/customization.md), and
[troubleshooting](https://github.com/armenusapp/sdk/blob/main/docs/troubleshooting.md).

The component exposes outer `style`, `arLabel`, `interactionEnabled`, `footer`,
`onEnterAr` and `onError`. The internal stage, button and note currently use fixed
styles. Outer `style` does not theme those elements. A universal native theme
object is not part of the API. Run CocoaPods for iOS in a native development build;
this native module is not available in a stock Expo Go runtime.
