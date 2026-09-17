"use client";

import { ArmenusError } from "../errors.js";
import type { EmbedConfig, EmbedItem } from "../types.js";
import { useEffect, useState } from "react";
import { useArmenusClient } from "./provider.js";

export interface AsyncState<T> {
  data: T | null;
  /** True until the first result or error arrives. */
  loading: boolean;
  error: ArmenusError | null;
}

const PENDING = { data: null, loading: true, error: null } as const;

/**
 * One dish, by Armenus id.
 *
 * `itemId` may be null, which is not an error state — it is a card whose row
 * has not resolved yet. Treating it as one would make every list flash an
 * error on first paint.
 */
export function useArmenusItem(itemId: string | null): AsyncState<EmbedItem> {
  const client = useArmenusClient();
  const [state, setState] = useState<AsyncState<EmbedItem>>(PENDING);

  useEffect(() => {
    if (!itemId) {
      setState({ data: null, loading: false, error: null });
      return;
    }

    /*
     * Aborted on unmount AND on id change. The second is what stops a fast
     * scroll through a list from settling on whichever response happened to
     * land last rather than the one belonging to the current id.
     */
    const controller = new AbortController();
    setState(PENDING);

    client
      .item(itemId, controller.signal)
      .then((data) => {
        if (!controller.signal.aborted) {
          setState({ data, loading: false, error: null });
        }
        return data;
      })
      .catch((error: unknown) => {
        if (controller.signal.aborted) return;
        setState({ data: null, loading: false, error: toArmenusError(error) });
      });

    return () => controller.abort();
  }, [client, itemId]);

  return state;
}

/** One dish, by your own identifier. */
export function useArmenusItemByRef(
  merchantId: string | null,
  externalRef: string | null,
): AsyncState<EmbedItem> {
  const client = useArmenusClient();
  const [state, setState] = useState<AsyncState<EmbedItem>>(PENDING);

  useEffect(() => {
    if (!merchantId || !externalRef) {
      setState({ data: null, loading: false, error: null });
      return;
    }

    const controller = new AbortController();
    setState(PENDING);

    client
      .itemByRef(merchantId, externalRef, controller.signal)
      .then((data) => {
        if (!controller.signal.aborted) {
          setState({ data, loading: false, error: null });
        }
        return data;
      })
      .catch((error: unknown) => {
        if (controller.signal.aborted) return;
        setState({ data: null, loading: false, error: toArmenusError(error) });
      });

    return () => controller.abort();
  }, [client, merchantId, externalRef]);

  return state;
}

/** Every dish on a merchant. */
export function useArmenusItems(
  merchantId: string | null,
  options: { withModel?: boolean; limit?: number } = {},
): AsyncState<EmbedItem[]> {
  const client = useArmenusClient();
  const [state, setState] = useState<AsyncState<EmbedItem[]>>(PENDING);

  // Destructured so the effect depends on the values rather than on an options
  // object that is a fresh literal on every render.
  const { withModel, limit } = options;

  useEffect(() => {
    if (!merchantId) {
      setState({ data: null, loading: false, error: null });
      return;
    }

    const controller = new AbortController();
    setState(PENDING);

    client
      .items(
        merchantId,
        {
          ...(withModel === undefined ? {} : { withModel }),
          ...(limit === undefined ? {} : { limit }),
        },
        controller.signal,
      )
      .then((list) => {
        if (!controller.signal.aborted) {
          setState({ data: list.items, loading: false, error: null });
        }
        return list;
      })
      .catch((error: unknown) => {
        if (controller.signal.aborted) return;
        setState({ data: null, loading: false, error: toArmenusError(error) });
      });

    return () => controller.abort();
  }, [client, merchantId, withModel, limit]);

  return state;
}

/**
 * What the key in hand can see.
 *
 * Worth calling once at startup even if the result goes unused: it is what
 * turns a revoked key from "the catalogue looks empty" into a loud error at a
 * point where somebody is still looking at the console.
 */
export function useArmenusConfig(): AsyncState<EmbedConfig> {
  const client = useArmenusClient();
  const [state, setState] = useState<AsyncState<EmbedConfig>>(PENDING);

  useEffect(() => {
    const controller = new AbortController();
    client
      .config(controller.signal)
      .then((data) => {
        if (!controller.signal.aborted) {
          setState({ data, loading: false, error: null });
        }
        return data;
      })
      .catch((error: unknown) => {
        if (controller.signal.aborted) return;
        setState({ data: null, loading: false, error: toArmenusError(error) });
      });
    return () => controller.abort();
  }, [client]);

  return state;
}

function toArmenusError(error: unknown): ArmenusError {
  return error instanceof ArmenusError
    ? error
    : new ArmenusError(0, "unknown_error", String(error));
}
