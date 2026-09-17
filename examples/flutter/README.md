# Armenus Flutter example

A dish grid and a detail screen where the dish can be placed on a real table.

## Run it

The plugin has native code, so this needs a real device or simulator — and AR
itself needs a real device, since neither simulator has a camera.

```bash
flutter pub get
flutter run --dart-define=ARMENUS_KEY=pk_live_...
```

Optional defines: `ARMENUS_MERCHANT_ID`, `ARMENUS_BASE_URL`.

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
