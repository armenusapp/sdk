# @armenus/sdk-react

Render Armenus dishes in 3D and AR on the web.

```bash
npm install @armenus/sdk-react
```

```tsx
import { ArmenusProvider, ArmenusModel, useArmenusItem } from "@armenus/sdk-react";
import "@armenus/sdk-react/styles.css";

function App() {
  return (
    <ArmenusProvider publishableKey="pk_...">
      <Dish itemId="..." />
    </ArmenusProvider>
  );
}

function Dish({ itemId }: { itemId: string }) {
  const { data, loading, error } = useArmenusItem(itemId);
  if (error) return <p>{error.message}</p>;
  return <ArmenusModel item={data} arLabel="See it on your table" />;
}
```

## What it renders

`<model-viewer>` under the hood — the only thing that reaches all three browser AR mechanisms (WebXR, Scene Viewer, AR Quick Look) from one element, and which already solves the mobile WebGL pitfalls hand-rolled Three.js gets wrong: one renderer per page, correct glTF scene traversal, normalised touch input, and context-loss recovery.

The library is ~300 kB and is imported **on mount, never at module scope**, so it never lands in your initial bundle.

## Notes

- **`ar-scale` is `fixed`.** The mesh is already scaled to the dish's real dimensions, which is the entire question a diner is asking. `auto` hands that back to the user as a pinch gesture.
- **`touch-action` is `none`.** With `pan-y` the page claims every vertical drag, so dragging on the model scrolls the page instead of tilting the dish — the first thing anyone tries. The stage is a fixed-height box, so the page still scrolls from outside it.
- **Styles are optional.** `styles.css` is plain CSS with everything overridable through `--armenus-*` custom properties. Pass `className` and style it yourself if you would rather; it ships no utility-class dependency, since this has to work in Tailwind, CSS modules, styled-components and nothing at all.
- **Driving AR yourself.** `<ArmenusModel>` renders its own AR button into model-viewer's slot. To use your own, take a ref to the element and call `activateAR()`.

## Hooks

`useArmenusItem`, `useArmenusItemByRef`, `useArmenusItems`, `useArmenusConfig` — each returns `{ data, loading, error }`.

All of them accept `null` for their id and treat it as "not resolved yet" rather than an error, so a list does not flash an error on first paint. Requests abort on unmount _and_ on id change, so a fast scroll settles on the response belonging to the current id rather than whichever landed last.
