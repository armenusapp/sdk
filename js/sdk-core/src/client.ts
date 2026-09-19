import { ArmenusError } from "./errors.js";
import type { EmbedConfig, EmbedItem, EmbedItemList } from "./types.js";

export interface ArmenusClientOptions {
  /** Publishable key, `pk_...`. Safe to ship in a bundle by construction. */
  publishableKey: string;
  /** Override for self-hosted or staging deployments. */
  baseUrl?: string;
  /**
   * Per-request ceiling in milliseconds.
   *
   * Exists because the default in every fetch implementation is "wait
   * forever", and the caller here is usually a phone rendering a product card.
   * A dish card that shows its photo after four seconds is a working card; one
   * that spins until the socket dies is a broken screen.
   */
  timeoutMs?: number;
  /**
   * Attempts for retryable failures, including the first. 1 disables retries.
   *
   * Only idempotent GETs exist in this API, so retrying is always safe here —
   * that is a property of the embed surface being read-only, not a general
   * licence, and it is why this is on by default when it usually should not be.
   */
  retries?: number;
  /** Injectable for tests and for runtimes with a non-global fetch. */
  fetch?: typeof globalThis.fetch;
}

const DEFAULT_BASE_URL = "https://api.armenus.app/v1";
const DEFAULT_TIMEOUT_MS = 8000;
const DEFAULT_RETRIES = 2;

interface ApiErrorBody {
  error?: string;
  message?: string;
  details?: unknown;
}

/**
 * Client for the Armenus embed API.
 *
 * Read-only, because the credential it holds is public. Anything that costs
 * money or changes data needs the secret partner key and a server to hold it.
 */
export class ArmenusClient {
  private readonly key: string;
  private readonly baseUrl: string;
  private readonly timeoutMs: number;
  private readonly retries: number;
  private readonly doFetch: typeof globalThis.fetch;

  constructor(options: ArmenusClientOptions) {
    if (!options.publishableKey?.startsWith("pk_")) {
      /*
       * Thrown at construction rather than on first request, and it is worth
       * the strictness. The overwhelmingly common integration mistake is
       * pasting the secret `ak_` key into client code — it would work, which
       * is exactly the problem, and it would work all the way to production.
       * Failing here turns a silent credential leak into a build-time error.
       */
      throw new ArmenusError(
        0,
        "invalid_key",
        options.publishableKey?.startsWith("ak_")
          ? "That is a secret API key. Never ship an ak_ key in client code — use a publishable pk_ key."
          : "A publishable key (pk_...) is required.",
      );
    }

    this.key = options.publishableKey;
    // Trailing slashes make every joined path double-slashed; normalise once.
    this.baseUrl = (options.baseUrl ?? DEFAULT_BASE_URL).replace(/\/+$/, "");
    this.timeoutMs = options.timeoutMs ?? DEFAULT_TIMEOUT_MS;
    this.retries = Math.max(1, options.retries ?? DEFAULT_RETRIES);
    this.doFetch = options.fetch ?? globalThis.fetch.bind(globalThis);
  }

  /**
   * What this key can see.
   *
   * Call it once at startup. It is the only way to find out that a key is
   * revoked or mistyped before the app has rendered a screen full of dishes
   * with no models and concluded the catalogue is empty.
   */
  config(signal?: AbortSignal): Promise<EmbedConfig> {
    return this.request<EmbedConfig>("/embed/config", signal);
  }

  /** One dish, by Armenus id. */
  item(itemId: string, signal?: AbortSignal): Promise<EmbedItem> {
    return this.request<EmbedItem>(
      `/embed/items/${encodeURIComponent(itemId)}`,
      signal,
    );
  }

  /**
   * One dish, by your own identifier.
   *
   * The route that makes an integration cheap: a host app already has its own
   * product id on the screen it is rendering, so it never has to store ours.
   */
  itemByRef(
    merchantId: string,
    externalRef: string,
    signal?: AbortSignal,
  ): Promise<EmbedItem> {
    return this.request<EmbedItem>(
      `/embed/merchants/${encodeURIComponent(merchantId)}/items/by-ref/${encodeURIComponent(externalRef)}`,
      signal,
    );
  }

  /** Every dish on one merchant. */
  items(
    merchantId: string,
    options: { withModel?: boolean; limit?: number; offset?: number } = {},
    signal?: AbortSignal,
  ): Promise<EmbedItemList> {
    const query = new URLSearchParams();
    if (options.withModel) query.append("withModel", "true");
    if (options.limit !== undefined) query.append("limit", String(options.limit));
    if (options.offset !== undefined) query.append("offset", String(options.offset));

    const suffix = query.toString() ? `?${query.toString()}` : "";
    return this.request<EmbedItemList>(
      `/embed/merchants/${encodeURIComponent(merchantId)}/items${suffix}`,
      signal,
    );
  }

  /**
   * Several dishes by id, in one request.
   *
   * A product grid needs twenty models at once, and twenty round trips from a
   * phone on restaurant wifi is the difference between a grid that pops in and
   * one that trickles. Capped at 50 by the API.
   */
  itemsByIds(ids: string[], signal?: AbortSignal): Promise<EmbedItemList> {
    if (ids.length === 0) {
      // Short-circuited rather than sent: the API would reject an empty `ids`
      // as malformed, and an empty request list is a perfectly ordinary state
      // for a grid that has not resolved its rows yet.
      return Promise.resolve({ items: [], version: "" });
    }
    const query = new URLSearchParams({ ids: ids.join(",") });
    return this.request<EmbedItemList>(`/embed/items?${query.toString()}`, signal);
  }

  /* -- transport --------------------------------------------------------- */

  private async request<T>(path: string, signal?: AbortSignal): Promise<T> {
    let lastError: ArmenusError | undefined;

    for (let attempt = 0; attempt < this.retries; attempt += 1) {
      if (signal?.aborted) throw new ArmenusError(0, "cancelled", "Request cancelled");
      try {
        return await this.attempt<T>(path, signal);
      } catch (error) {
        const failure =
          error instanceof ArmenusError
            ? error
            : new ArmenusError(0, "network_error", String(error));

        // A caller-driven abort is not a failure to retry around — the screen
        // it was feeding is gone.
        if (signal?.aborted) throw failure;
        if (!failure.isRetryable) throw failure;

        lastError = failure;

        if (attempt < this.retries - 1) {
          // Exponential, and jittered. Without jitter a restaurant full of
          // phones that all failed on the same blip retries in lockstep and
          // reproduces it.
          const backoff = 200 * 2 ** attempt;
          await sleep(backoff + Math.random() * backoff);
        }
      }
    }

    throw lastError ?? new ArmenusError(0, "network_error", "Request failed");
  }

  private async attempt<T>(path: string, signal?: AbortSignal): Promise<T> {
    /*
     * A timeout controller per attempt, chained to the caller's signal.
     * `AbortSignal.any` would be tidier but is too new to rely on in a package
     * that has to run on whatever JavaScriptCore ships in an old React Native.
     */
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.timeoutMs);
    const forwardAbort = () => controller.abort();
    signal?.addEventListener("abort", forwardAbort);

    try {
      const response = await this.doFetch(`${this.baseUrl}${path}`, {
        method: "GET",
        headers: {
          authorization: `Bearer ${this.key}`,
          accept: "application/json",
        },
        signal: controller.signal,
      });

      if (!response.ok) {
        // The API always sends a JSON error body, but a proxy or a captive
        // portal in between may not — so parsing it must never be what
        // produces the error the caller sees.
        let body: ApiErrorBody = {};
        try {
          body = (await response.json()) as ApiErrorBody;
        } catch {
          body = {};
        }
        throw new ArmenusError(
          response.status,
          body.error ?? "http_error",
          body.message ?? `Request failed with status ${response.status}`,
          body.details,
        );
      }

      return (await response.json()) as T;
    } catch (error) {
      if (error instanceof ArmenusError) throw error;
      if (controller.signal.aborted && !signal?.aborted) {
        throw new ArmenusError(
          0,
          "timeout",
          `Request timed out after ${this.timeoutMs}ms`,
        );
      }
      throw new ArmenusError(0, "network_error", String(error));
    } finally {
      clearTimeout(timer);
      signal?.removeEventListener("abort", forwardAbort);
    }
  }
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
