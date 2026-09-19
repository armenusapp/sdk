# Armenus React Native example

A dish list and a detail screen where the dish can be placed on a real table.

## Run it

This SDK has native modules, so **Expo Go will not work** — it ships a fixed
set of native code and cannot load ours. Use a development build:

While npm publication is pending, install the matching integration archives:

```bash
npm install /path/to/armenus-sdk-core-0.1.0.tgz /path/to/armenus-sdk-react-native-0.1.0.tgz
cp .env.example .env      # add your publishable key

npx expo run:ios          # or: npx expo run:android
```

Both platforms use React Native autolinking. For a bare project, run `pod install`
in `ios` and rebuild the native apps. Do not add a second `ArmenusPackage()` when
Android autolinking is enabled. The Expo example sets Kotlin 2.0.21 through
`expo-build-properties` and pins the Kotlin Gradle dependency with the included
config plugin. Android also needs Java 17 and API 24 or later.

## What to look at

| File                 | Shows                                                  |
| -------------------- | ------------------------------------------------------ |
| `src/App.tsx`        | Provider setup, and failing loudly on a bad key.       |
| `src/MenuScreen.tsx` | A `FlatList` of dishes, and why the cards are posters. |
| `src/DishScreen.tsx` | `<ArmenusModel>`, AR, and prefetching the next rows.   |

## The two things that bite

**`interactionEnabled={false}` inside the list.** The model's drag handling and
the `FlatList`'s scrolling fight over the same vertical gesture. A card that
swallows it makes the whole feed feel stuck.

**iOS needs the USDZ for the preview, not just for AR.** SceneKit cannot open a
GLB, so a dish still waiting on conversion shows its poster on iPhone while
showing a spinning model on Android. That is expected — `resolvePresentation()`
decides, and `<ArmenusModel>` already does the right thing.
