# Armenus React Native example

A dish list and a detail screen where the dish can be placed on a real table.

## Run it

This SDK has native modules, so **Expo Go will not work** — it ships a fixed
set of native code and cannot load ours. Use a development build:

```bash
npm install
cp .env.example .env      # add your publishable key

npx expo run:ios          # or: npx expo run:android
```

For a bare React Native project the only extra step is Android: add
`ArmenusPackage()` to your `MainApplication` package list. iOS is autolinked by
CocoaPods.

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
