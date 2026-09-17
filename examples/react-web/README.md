# Armenus web example

A dish grid and a detail view with 3D and AR, in about 200 lines of React.

## Run it

```bash
pnpm install
cp .env.example .env      # add your publishable key
pnpm --filter @armenus/example-react-web dev
```

Then open http://localhost:5173.

This example is part of the monorepo workspace, so it builds against the local
`@armenus/sdk-react` — which means it also proves the SDK's public API compiles
as documented. Outside the repo, replace the `workspace:*` dependency with a
version range.

## What to look at

| File           | Shows                                                               |
| -------------- | ------------------------------------------------------------------- |
| `src/App.tsx`  | Provider setup, and failing loudly on a missing key.                |
| `src/Menu.tsx` | `config()` first, `withModel` filtering, and why cards are posters. |
| `src/Dish.tsx` | `<ArmenusModel>`, the AR footer, and real-world size.               |

## Notes

**AR needs HTTPS.** `localhost` is treated as secure so the 3D view works, but
placing a dish on a table from another device needs a real certificate — a
tunnel is the usual way to get one in development.

**Desktop has no AR.** That is expected: the SDK renders the model and tells
the user to scan the QR code with a phone. Test AR on an actual handset.
