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
| Android      | Native layout around `ArmenusModelView`; AR label, accent color and interaction controls | Stage and typography are fixed; no cross-platform theme object. |

## Before copying an example

Each card accepts an `EmbedItem` already fetched by your SDK client.
`priceLabel` is text formatted by your app, and `onAdd` is your own cart callback.
See the [setup guides](https://developers.armenus.app/quickstart) for fetching items.

## React: a branded dish card with your own order button

Pass an EmbedItem returned by the client or a data hook. priceLabel is a formatted price from your app; onAdd connects to your cart. Import the SDK CSS once, then brand.css. The footer receives the resolved AR capability, so it can explain when placement is unavailable. onEnterAr records an AR request, not successful placement. In Next.js, keep this component in a client file.

```tsx
"use client";
import { ArmenusModel, type EmbedItem } from "@armenus/sdk-react";
import "@armenus/sdk-react/styles.css";
import "./brand.css";

type DishCardProps = {
  item: EmbedItem;
  priceLabel: string;
  onAdd: (item: EmbedItem) => void;
};

export function DishCard({ item, priceLabel, onAdd }: DishCardProps) {
  return (
    <article className="dish-card">
      <ArmenusModel
        item={item}
        className="restaurant-viewer"
        alt={`Interactive 3D view of ${item.name}`}
        arLabel="See it on your table"
        footer={({ ar }) => (
          <p className="dish-hint">
            {ar.supported ? "Check the portion on your table." : ar.reason}
          </p>
        )}
        onEnterAr={(dish) => console.info("AR requested", dish.id)}
      />
      <div className="dish-details">
        <h3>{item.name}</h3>
        <p>{priceLabel}</p>
        <button type="button" onClick={() => onAdd(item)}>Add to order</button>
      </div>
    </article>
  );
}
```

```css
/* brand.css — loaded after the SDK stylesheet */
.dish-card {
  max-width: 420px;
  padding: 16px;
  border: 1px solid #dce3d8;
  border-radius: 24px;
  background: #fff;
  color: #183127;
}
.armenus-viewer.restaurant-viewer {
  --armenus-accent: #244d3b;
  --armenus-on-accent: #ffffff;
  --armenus-surface: #f3f5ec;
  --armenus-muted: #53614c;
  --armenus-radius: 20px;
  --armenus-font: inherit;
}
.restaurant-viewer .armenus-stage { aspect-ratio: 4 / 3; }
.dish-hint { color: #53614c; font-size: 0.875rem; }
.dish-details { padding: 8px; }
.dish-details h3 { margin: 0; }
.dish-details button {
  min-height: 44px;
  width: 100%;
  border: 0;
  border-radius: 12px;
  background: #244d3b;
  color: #fff;
  font: inherit;
  cursor: pointer;
}
.dish-details button:focus-visible {
  outline: 3px solid #244d3b;
  outline-offset: 3px;
}
```

## React: dark mode and a compact square preview

Add data-theme="dark" to your app shell when the user selects dark mode. These rules go after the previous CSS. Variables must be set on the viewer itself: defaults declared there override values inherited only from a parent. Use className="restaurant-viewer compact-viewer" for a square stage. These overrides retain the SDK loading states and keyboard focus styles.

```css
[data-theme="dark"] .dish-card {
  background: #14231d;
  border-color: #3c5145;
  color: #f4f7f2;
}
[data-theme="dark"] .armenus-viewer.restaurant-viewer {
  --armenus-surface: #20372b;
  --armenus-accent: #bce2bd;
  --armenus-on-accent: #122719;
  --armenus-muted: #c0cec0;
}
[data-theme="dark"] .dish-hint { color: #c0cec0; }
.restaurant-viewer.compact-viewer .armenus-stage { aspect-ratio: 1; }
.restaurant-viewer.compact-viewer .armenus-ar-button {
  border-radius: 12px;
  font-size: 0.875rem;
  min-height: 44px;
}
```

## React Native: a card that works inside a scrolling menu

Use this card in a FlatList with keyExtractor={(item) => item.id}. Disabling interaction lets scrolling gestures reach the list; use interactionEnabled={true} on a dedicated detail screen. style changes viewer spacing; the card background, title and order button below are your own components. The built-in AR button keeps its native SDK styling. Errors appear as text without blocking the rest of the card.

```tsx
import { useState } from "react";
import { Pressable, StyleSheet, Text, View } from "react-native";
import { ArmenusModel, type EmbedItem } from "@armenus/sdk-react-native";

type Props = {
  item: EmbedItem;
  priceLabel: string;
  onAdd: (item: EmbedItem) => void;
};

export function DishCard({ item, priceLabel, onAdd }: Props) {
  const [error, setError] = useState<string | null>(null);
  return (
    <View style={styles.card}>
      <Text style={styles.title}>{item.name}</Text>
      <ArmenusModel
        item={item}
        style={{ marginVertical: 12 }}
        arLabel="See it on your table"
        interactionEnabled={false}
        footer={({ ar }) => (
          <Text style={styles.hint}>
            {ar.supported ? "Preview the portion in your space." : ar.reason}
          </Text>
        )}
        onEnterAr={(dish) => console.info("AR requested", dish.id)}
        onError={setError}
      />
      {error ? <Text accessibilityRole="alert">{error}</Text> : null}
      <Text>{priceLabel}</Text>
      <Pressable
        accessibilityRole="button"
        accessibilityLabel={`Add ${item.name} to order`}
        style={styles.button}
        onPress={() => onAdd(item)}
      >
        <Text style={styles.buttonText}>Add to order</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  card: { padding: 16, marginBottom: 16, borderRadius: 24, backgroundColor: "#f3f5ec" },
  title: { fontSize: 22, fontWeight: "600", color: "#244d3b" },
  hint: { color: "#53614c", marginTop: 8 },
  button: { marginTop: 12, minHeight: 44, padding: 12, borderRadius: 12,
    backgroundColor: "#244d3b", alignItems: "center" },
  buttonText: { color: "#fff", fontWeight: "600" },
});
```

## Flutter: a wide preview inside a Material card

Use DishCard inside a MaterialApp. The 4:3 aspectRatio sizes the inline stage. Card, Text and FilledButton style the surrounding UI; their theme does not recolor every internal viewer element. Pass your formatted price and cart callback. This version disables model dragging for a ListView; enable it on a detail page.

```dart
import 'package:armenus/armenus.dart';
import 'package:flutter/material.dart';

class DishCard extends StatelessWidget {
  const DishCard({
    super.key,
    required this.item,
    required this.priceLabel,
    required this.onAdd,
  });

  final EmbedItem item;
  final String priceLabel;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xfff3f5ec),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(item.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            ArmenusModel(
              key: ValueKey(item.id),
              item: item,
              aspectRatio: 4 / 3,
              arLabel: 'See it on your table',
              interactionEnabled: false,
              onEnterAr: (dish) => debugPrint('AR requested: ${dish.id}'),
              onError: (message) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(message)),
                );
              },
            ),
            const SizedBox(height: 12),
            Text(priceLabel),
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xff244d3b),
                foregroundColor: Colors.white,
                minimumSize: const Size(44, 44),
              ),
              onPressed: onAdd,
              child: const Text('Add to order'),
            ),
          ],
        ),
      ),
    );
  }
}
```

## SwiftUI: compose a dish detail card

This example targets iOS 16 or later so the wrapper can size its native content from the proposed width. The rounded background, typography and order button belong to your app. tint styles the SwiftUI order button; it does not set the UIKit-backed viewer’s AR button color. Use the next UIKit example when you need that accent color.

```swift
import Armenus
import SwiftUI

@available(iOS 16.0, *)
struct DishCard: View {
  let item: EmbedItem
  let priceLabel: String
  let onAdd: () -> Void
  @State private var modelError: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(item.name).font(.title2.bold())
      ArmenusModel(
        item: item,
        arLabel: "See it on your table",
        interactionEnabled: true,
        onEnterAR: { dish in print("AR requested: \(dish.id)") },
        onError: { modelError = $0 }
      )
      if let modelError {
        Text(modelError).font(.footnote).foregroundStyle(.secondary)
      }
      Text(priceLabel).font(.headline)
      Button("Add to order", action: onAdd)
        .buttonStyle(.borderedProminent)
        .tint(Color(red: 0.14, green: 0.30, blue: 0.23))
    }
    .padding(16)
    .background(Color(red: 0.95, green: 0.96, blue: 0.93))
    .clipShape(RoundedRectangle(cornerRadius: 24))
  }
}
```

## UIKit: change the native AR button color

Present this view controller from your existing navigation. Pinning the viewer’s width allows its square stage and capability note to determine its height. accentColor changes the built-in AR button background; keep enough contrast with its white label. The system camera AR screen retains Apple’s own controls.

```swift
import Armenus
import UIKit

final class DishViewController: UIViewController {
  private let item: EmbedItem
  private let modelView = ArmenusModelView()

  init(item: EmbedItem) {
    self.item = item
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) { fatalError("Use init(item:)") }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground
    modelView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(modelView)
    NSLayoutConstraint.activate([
      modelView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
      modelView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
      modelView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
    ])
    modelView.accentColor = UIColor(red: 0.14, green: 0.30, blue: 0.23, alpha: 1)
    modelView.arLabel = "See it on your table"
    modelView.interactionEnabled = true
    modelView.onModelError = { message in print("Model error: \(message)") }
    modelView.onEnterAR = { dish in print("AR requested: \(dish.id)") }
    modelView.display(item)
  }
}
```

## Android / Kotlin: a Compose card with a native viewer

This recipe uses Jetpack Compose Material 3. AndroidView hosts ArmenusModelView; update applies the latest item and callbacks. accentColor changes the SDK AR button while Card and Button style your app’s surrounding UI. display(item) is safe to call from update. The native stage is square; fillMaxWidth supplies its width without imposing a second aspect ratio on the stage plus its note.

```kotlin
import android.graphics.Color as AndroidColor
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import app.armenus.sdk.ArmenusModelView
import app.armenus.sdk.EmbedItem

@Composable
fun DishCard(
  item: EmbedItem,
  priceLabel: String,
  onAdd: () -> Unit,
  onModelError: (String) -> Unit,
) {
  Card(colors = CardDefaults.cardColors(containerColor = Color(0xFFF3F5EC))) {
    Column(
      modifier = Modifier.padding(16.dp),
      verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
      Text(item.name, style = MaterialTheme.typography.titleLarge)
      AndroidView(
        modifier = Modifier.fillMaxWidth(),
        factory = { context -> ArmenusModelView(context) },
        update = { viewer ->
          viewer.accentColor = AndroidColor.rgb(36, 77, 59)
          viewer.arLabel = "See it on your table"
          viewer.interactionEnabled = false // Enable on a detail screen.
          viewer.onModelError = onModelError
          viewer.display(item)
        },
      )
      Text(priceLabel)
      Button(
        onClick = onAdd,
        modifier = Modifier.fillMaxWidth(),
        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF244D3B)),
      ) { Text("Add to order") }
    }
  }
}
```

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

UIKit and Android `ArmenusModelView` expose `accentColor` for the AR button.
The SwiftUI `ArmenusModel` wrapper does not currently forward it. See the
[iOS / Swift guide](https://developers.armenus.app/swift) and
[Android / Kotlin guide](https://developers.armenus.app/kotlin).
