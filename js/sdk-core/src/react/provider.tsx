"use client";

import { ArmenusClient, type ArmenusClientOptions } from "../client.js";
import { createContext, useContext, useMemo, type ReactNode } from "react";

const ClientContext = createContext<ArmenusClient | null>(null);

export interface ArmenusProviderProps extends ArmenusClientOptions {
  children: ReactNode;
}

/**
 * Supplies the client to everything beneath it.
 *
 * Mount once, near the root. The client is memoised on the options that
 * actually change its behaviour rather than on the object identity, because
 * the natural way to write this —
 *
 *     <ArmenusProvider publishableKey={key} />
 *
 * — produces a fresh options object on every render of the parent. Keyed on
 * identity, that would rebuild the client each time and, more to the point,
 * re-run every hook subscribed to it.
 */
export function ArmenusProvider({ children, ...options }: ArmenusProviderProps) {
  const client = useMemo(
    () => new ArmenusClient(options),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [
      options.publishableKey,
      options.baseUrl,
      options.timeoutMs,
      options.retries,
      options.fetch,
    ],
  );

  return <ClientContext.Provider value={client}>{children}</ClientContext.Provider>;
}

export function useArmenusClient(): ArmenusClient {
  const client = useContext(ClientContext);
  if (!client) {
    throw new Error(
      'No Armenus client found. Wrap your app in <ArmenusProvider publishableKey="pk_...">.',
    );
  }
  return client;
}
