import { describe, expect, it, vi } from "vitest";
import { ArmenusClient } from "./client.js";

const response = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status, headers: { "content-type": "application/json" },
});

describe("ArmenusClient transport", () => {
  it("rejects secret keys before network access", () => {
    expect(() => new ArmenusClient({ publishableKey: "ak_secret" })).toThrow(/secret/i);
  });
  it("authenticates and encodes restaurant and catalogue identifiers", async () => {
    const fetch = vi.fn<typeof globalThis.fetch>().mockResolvedValue(response({ id: "dish" }));
    const client = new ArmenusClient({ publishableKey: "pk_test", baseUrl: "https://example.com/v1/", fetch });
    await client.itemByRef("restaurant/a", "SKU #1");
    expect(fetch).toHaveBeenCalledWith("https://example.com/v1/embed/merchants/restaurant%2Fa/items/by-ref/SKU%20%231", expect.objectContaining({
      headers: { authorization: "Bearer pk_test", accept: "application/json" },
    }));
  });
  it("lists dishes on React Native's URLSearchParams subset", async () => {
    const unsupported = vi.spyOn(URLSearchParams.prototype, "set").mockImplementation(() => {
      throw new Error("URLSearchParams.set is not implemented");
    });
    try {
      const fetch = vi.fn<typeof globalThis.fetch>().mockResolvedValue(response({ items: [] }));
      const client = new ArmenusClient({ publishableKey: "pk_test", fetch });
      await client.items("restaurant", { withModel: true, limit: 20, offset: 10 });
      expect(fetch.mock.calls[0]?.[0]).toBe("https://api.armenus.app/v1/embed/merchants/restaurant/items?withModel=true&limit=20&offset=10");
    } finally {
      unsupported.mockRestore();
    }
  });
  it("does not send an empty batch", async () => {
    const fetch = vi.fn<typeof globalThis.fetch>();
    const client = new ArmenusClient({ publishableKey: "pk_test", fetch });
    expect(await client.itemsByIds([])).toEqual({ items: [], version: "" });
    expect(fetch).not.toHaveBeenCalled();
  });
  it("does not retry revoked keys", async () => {
    const fetch = vi.fn<typeof globalThis.fetch>().mockResolvedValue(response({ error: "key_revoked", message: "Revoked" }, 403));
    const client = new ArmenusClient({ publishableKey: "pk_test", fetch });
    await expect(client.config()).rejects.toMatchObject({ status: 403, code: "key_revoked", isAuthError: true });
    expect(fetch).toHaveBeenCalledTimes(1);
  });
  it("preserves status when a proxy returns a non-JSON error", async () => {
    const fetch = vi.fn<typeof globalThis.fetch>().mockResolvedValue(new Response("No access", { status: 403 }));
    const client = new ArmenusClient({ publishableKey: "pk_test", fetch });
    await expect(client.config()).rejects.toMatchObject({ status: 403, code: "http_error" });
  });
  it("retries temporary failures and returns the successful response", async () => {
    const fetch = vi.fn<typeof globalThis.fetch>()
      .mockResolvedValueOnce(response({ error: "unavailable" }, 503))
      .mockResolvedValueOnce(response({ merchants: [] }));
    const client = new ArmenusClient({ publishableKey: "pk_test", fetch });
    expect(await client.config()).toEqual({ merchants: [] });
    expect(fetch).toHaveBeenCalledTimes(2);
  });
  it("does not start a request for an already cancelled screen", async () => {
    const fetch = vi.fn<typeof globalThis.fetch>().mockResolvedValue(response({ merchants: [] }));
    const client = new ArmenusClient({ publishableKey: "pk_test", fetch });
    const abort = new AbortController();
    abort.abort();
    await expect(client.config(abort.signal)).rejects.toMatchObject({ status: 0 });
    expect(fetch).not.toHaveBeenCalled();
  });
  it("reports a timeout and cancels the underlying request", async () => {
    let cancelled = false;
    const fetch: typeof globalThis.fetch = async (_, init) => new Promise((_, reject) => {
      init?.signal?.addEventListener("abort", () => {
        cancelled = true;
        reject(new Error("aborted"));
      });
    });
    const client = new ArmenusClient({ publishableKey: "pk_test", fetch, retries: 1, timeoutMs: 10 });
    await expect(client.config()).rejects.toMatchObject({ code: "timeout" });
    expect(cancelled).toBe(true);
  });
});
