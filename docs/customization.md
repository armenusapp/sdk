# Design and customization

You can build your own menu design around every SDK. Ready-made viewer theming
is strongest on React web; there is no shared theme object across all platforms.
The dashboard's Appearance settings style Armenus-hosted menus and do not
automatically theme a custom SDK application.

| SDK          | Supported controls                                                         | Current limitation                                                       |
| ------------ | -------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| Core JS      | Data client, custom fetch/base URL/timeouts/retries, presentation resolver | No UI; your app implements the whole design.                             |
| React web    | `className`, `alt`, `arLabel`, `footer`, `onEnterAr`; optional CSS         | No prop for arbitrary model-viewer attributes or a forwarded viewer ref. |
| React Native | Outer `style`, `arLabel`, `interactionEnabled`, `footer`, callbacks        | Internal stage, button and note use fixed styles.                        |
| Flutter      | `arLabel`, `interactionEnabled`, `aspectRatio`, callbacks                  | No comprehensive palette, typography or slot API.                        |
| Swift        | SwiftUI layout around `ArmenusModel`; `arLabel`, interaction, callbacks    | UIKit internals do not expose a full theme object.                       |
| Android      | Native layout around `ArmenusModelView`; AR label and interaction controls | Built-in internal presentation is fixed; no cross-platform theme object. |

## React example

Import the optional SDK stylesheet before your overrides:

```tsx
import { ArmenusModel, type EmbedItem } from "@armenus/sdk-react";
import "@armenus/sdk-react/styles.css";
import "./brand.css";

export function BrandedDish({ item }: { item: EmbedItem }) {
  return (
    <ArmenusModel
      item={item}
      className="restaurant-viewer"
      alt={`Interactive 3D view of ${item.name}`}
      arLabel="See it on your table"
      footer={() => <p>Prepared fresh in our kitchen.</p>}
      onEnterAr={(dish) => console.log("AR requested", dish.id)}
    />
  );
}
```

```css
.armenus-viewer.restaurant-viewer {
  --armenus-radius: 20px;
  --armenus-surface: #f3f5ec;
  --armenus-accent: #244d3b;
  --armenus-on-accent: #ffffff;
  --armenus-muted: #53614c;
  --armenus-font: inherit;
}
.restaurant-viewer .armenus-stage {
  aspect-ratio: 4 / 3;
}
```

The default stylesheet declares its variables on `.armenus-viewer`. Put your
overrides on that same element with a stronger selector, or later with equal
specificity. Setting variables only on a parent can be shadowed by the defaults.

| Variable              | Default           | Purpose                     |
| --------------------- | ----------------- | --------------------------- |
| `--armenus-radius`    | `0.875rem`        | Stage corner radius         |
| `--armenus-surface`   | `#f4f2f3`         | Stage background            |
| `--armenus-accent`    | `#dc2626`         | AR button and focus color   |
| `--armenus-on-accent` | `#fff`            | AR button text              |
| `--armenus-muted`     | `#6b5555`         | Loading and capability text |
| `--armenus-font`      | System sans-serif | Viewer UI typography        |

You may omit the stylesheet and style `.armenus-viewer`, `.armenus-stage`,
`.armenus-canvas`, `.armenus-ar-button`, `.armenus-placeholder`, `.armenus-poster`,
`.armenus-skeleton` and `.armenus-note` yourself. Preserve a visible loading state,
a sized stage, keyboard focus and a minimum 44px AR target.

`onEnterAr` reports activation, not successful placement or a completed order.
The stock component does not forward a model-viewer ref. If you need direct
`activateAR()` or arbitrary renderer attributes, use the core client with your
own viewer and capability handling.

## React Native example

```tsx
<ArmenusModel
  item={item}
  style={{ marginVertical: 16 }}
  arLabel="View in your space"
  interactionEnabled={false}
  footer={() => <Text>Ask our team about this dish.</Text>}
/>
```

Disable interaction in a scrolling row when gestures would otherwise compete.
The `style` prop changes the outer container; it does not recolor the internal
AR button. Do not rely on undocumented theme props.

## Model appearance is separate

`item.model.viewSettings` carries camera framing, target, field of view, exposure,
shadow intensity and automatic rotation. Each platform implements its rendering
settings; not every field maps identically across engines. These values are
separate from interface colors, fonts and spacing. Preserve the model's physical
scale for AR. System AR interfaces are controlled by the platform.

## Choosing a design approach

Use React's CSS API for branded web viewers. Use the built-in native components
when their controls fit your design. For a fully custom native experience,
compose the documented data/capability/AR APIs with your own UI and validate it
on devices. A complete native theme/slot API would require a future SDK change;
it is not available merely by changing the hosted menu theme.
