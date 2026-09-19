# Armenus Flutter example

A dish grid and a detail screen where the dish can be placed on a real table.

## Run it

The plugin has native code, so this needs a real device or simulator — and AR
itself needs a real device, since neither simulator has a camera.

Run this example from the repository so its local `armenus` dependency resolves.
Generate the Android and iOS project files once:

```bash
flutter create --platforms=android,ios --project-name armenus_example .
flutter pub get
flutter run --dart-define=ARMENUS_KEY=pk_live_...
```

Set the Android app’s `minSdk` to at least 24. Use Java 17 and Kotlin 2.0.21
or later. When copying this example into a separate project, replace the local
`armenus` path dependency with the git dependency in the Flutter SDK README.

Optional defines: `ARMENUS_MERCHANT_ID`, `ARMENUS_BASE_URL`. The restaurant ID
comes from `config()`; omit the override to use the first accessible restaurant.

## Run the native integration test

```bash
flutter test integration_test/native_smoke_test.dart -d <device-id>
```

On Android, the test serves its fixtures over local HTTP. Add
`<application android:usesCleartextTraffic="true"/>` inside the generated
`android/app/src/debug/AndroidManifest.xml` for this test. Keep this setting in
the debug manifest.

This test uses the included tiny fixtures, without a key or a live restaurant.
It checks download caching, native model rendering, replacing a model and clearing
the cache. Camera AR is tested separately on a supported physical phone.

## What to look at

| File                   | Shows                                           |
| ---------------------- | ----------------------------------------------- |
| `lib/main.dart`        | Client setup, and failing loudly without a key. |
| `lib/menu_screen.dart` | The grid, `config()` first, and prefetching.    |
| `lib/dish_screen.dart` | `ArmenusModel`, AR, and real-world size.        |

## The two things that bite

**`interactionEnabled: false` inside a scrollable.** The platform view and the
`ListView` fight over every vertical drag. A card that swallows it makes the
whole feed feel stuck.

**iOS needs the USDZ for the preview, not just for AR.** SceneKit cannot open a
GLB, so a dish still waiting on conversion shows its poster on iPhone while
showing a spinning model on Android. `resolvePresentation()` decides this, and
`ArmenusModel` already does the right thing — do not reach for `model.glbUrl`
yourself on iOS.
