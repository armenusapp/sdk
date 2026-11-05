# Z Burger House — fresh menu preset

Owner-specific draft based on the November 5 reference. Uses the published dish photographs and catalogue prices. No production theme or catalogue changes have been applied.

## Preview

From `apps/web`, run:

```sh
API_INTERNAL_URL=https://api.armenus.app pnpm exec next dev --hostname 127.0.0.1 --port 3026
```

Open `http://127.0.0.1:3026/dev/zburgerhouse-preview`. This development-only route fetches the current public menu, overlays the draft theme, and supports dish sheets and saved dishes. Assistant requests use the API configured above. It returns 404 in production. Local saved dishes belong only to this browser origin.

The authoring session could not start a server because binding sockets returned EPERM. Browser layout and touch interaction review remain required.

## Files and behavior

- `theme.json`: warm white/green palette, six category groups, photo-first 3D behavior, and explicit item-family IDs.
- `menu.css`: restaurant-scoped compact hero, food photographs, mobile cards, selected filter treatment, and help buttons. Yellow is decorative; text uses darker accessible colors.
- `menu.js`: budget/taste prompts through `armenus.openAssistant(prompt)`. Only writes into the reserved custom-code slot.
- `families.json`: reviewable list of the 55 matched portion/combo pairs and original prices at authoring time. Prices here are audit information, never a runtime price source.

All canonical item IDs, routes, options, prices, AI references and saved selections remain unchanged. Choosing a portion/combo changes the card's photo, price, link and save target. Filtering happens before grouping, so a hidden option cannot leak back through a grouped card. Result counts count displayed cards. New categories not yet assigned to a group remain visible.

The family map is conservative: only matching names with `1/2`, `Sandwich`, or `combo` removed were grouped within the same category. Differently spelled names and cross-category duplicates remain separate for owner review. No products were deleted or converted in the database.

## Applying after review

Deploy the accompanying opt-in theme/component support before applying this preset. Merge `theme.json` into Z Burger House's theme and paste `menu.css` / `menu.js` into its custom-code settings. Use the normal published-menu workflow and retain a backup of the existing theme/custom code.

Do not replace the full catalogue settings using a public-menu response: public responses deliberately omit private assistant facts and instructions. Preserve the existing contact/halal facts. The assistant may be renamed to “Help me choose” in its settings. The prompt buttons request matching explanations, drinks and optional sides while respecting the customer's budget and diet.

3D renderers are mounted only after a request with `modelLoading: "on-demand"`. Existing restaurants retain eager behavior unless they opt in. Dish photographs keep the existing viewport-gated lazy loading.
