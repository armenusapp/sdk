import { ArmenusProvider } from "@armenus/sdk-react";
import "@armenus/sdk-react/styles.css";
import { useState } from "react";
import { Menu } from "./Menu";

/**
 * Armenus web example.
 *
 * A menu grid, and a detail view where the dish can be placed on a real table.
 * Everything AR-related is handled by <ArmenusModel>; the rest of this project
 * is ordinary React so it is obvious which parts are the SDK.
 */

const KEY = import.meta.env.VITE_ARMENUS_KEY as string | undefined;
const BASE_URL = import.meta.env.VITE_ARMENUS_BASE_URL as string | undefined;

export function App() {
  /*
   * Selection lives here rather than in the router, because this example has
   * no router. In a real app the dish would be a route so it can be linked to
   * and shared — which is most of the point of a menu.
   */
  const [selectedId, setSelectedId] = useState<string | null>(null);

  if (!KEY) {
    return (
      <div className="setup">
        <h1>Almost there</h1>
        <p>
          Copy <code>.env.example</code> to <code>.env</code> and set{" "}
          <code>VITE_ARMENUS_KEY</code> to a publishable key.
        </p>
        <p>
          Get one from the dashboard under <b>Settings → Embedding</b>, or with{" "}
          <code>POST /v1/partner/publishable-keys</code>.
        </p>
      </div>
    );
  }

  return (
    <ArmenusProvider publishableKey={KEY} {...(BASE_URL ? { baseUrl: BASE_URL } : {})}>
      <Menu selectedId={selectedId} onSelect={setSelectedId} />
    </ArmenusProvider>
  );
}
