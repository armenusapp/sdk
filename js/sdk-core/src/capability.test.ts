import { describe, expect, it } from "vitest";
import {
  buildSceneViewerUrl,
  detectBrowserPlatform,
  resolvePresentation,
} from "./capability.js";
import type { EmbedModel } from "./types.js";

const model = (over: Partial<EmbedModel> = {}): EmbedModel => ({
  id: "m1",
  glbUrl: "https://cdn.example/dish.glb",
  usdzUrl: "https://cdn.example/dish.usdz",
  usdzStatus: "ready",
  posterUrl: "https://cdn.example/dish.webp",
  physicalSizeM: 0.27,
  glbBytes: 157_000,
  viewSettings: {
    cameraOrbit: "0deg 75deg 105%",
    cameraTarget: "auto auto auto",
    fieldOfView: "auto",
    exposure: 1,
    shadowIntensity: 1,
    autoRotate: true,
    arScale: 1,
  },
  ...over,
});

describe("resolvePresentation — iOS", () => {
  it("renders the USDZ inline and offers Quick Look", () => {
    const result = resolvePresentation({ platform: "ios", model: model() });
    expect(result.inline).toEqual({
      kind: "usdz",
      url: "https://cdn.example/dish.usdz",
    });
    expect(result.ar.mode).toBe("quick-look");
    expect(result.ar.supported).toBe(true);
  });

  it("falls back to the poster INLINE when the USDZ is missing", () => {
    /*
     * The rule most likely to be got wrong by anyone porting this. On iOS a
     * missing USDZ is not merely "no AR button" as it is on the web — SceneKit
     * cannot open a GLB, so there is no mesh to draw at all and the preview
     * itself degrades to a photograph.
     */
    const result = resolvePresentation({
      platform: "ios",
      model: model({ usdzUrl: null, usdzStatus: "processing" }),
    });
    expect(result.inline).toEqual({
      kind: "poster",
      url: "https://cdn.example/dish.webp",
    });
    expect(result.inline.kind).not.toBe("glb");
    expect(result.ar.supported).toBe(false);
    expect(result.ar.blockedOnConversion).toBe(true);
  });

  it("says a failed conversion is unavailable, not still preparing", () => {
    // "Check back shortly" on a permanently failed model is a lie the UI
    // repeats forever.
    const result = resolvePresentation({
      platform: "ios",
      model: model({ usdzUrl: null, usdzStatus: "failed" }),
    });
    expect(result.ar.blockedOnConversion).toBe(false);
    expect(result.ar.reason).toMatch(/unavailable/i);
  });

  it("degrades to nothing renderable when there is no poster either", () => {
    const result = resolvePresentation({
      platform: "ios",
      model: model({ usdzUrl: null, posterUrl: null }),
    });
    expect(result.inline).toEqual({ kind: "none" });
  });
});

describe("resolvePresentation — Android", () => {
  it("renders the GLB inline and offers Scene Viewer when ARCore is present", () => {
    const result = resolvePresentation({
      platform: "android",
      model: model(),
      arCoreAvailable: true,
    });
    expect(result.inline).toEqual({
      kind: "glb",
      url: "https://cdn.example/dish.glb",
    });
    expect(result.ar.mode).toBe("scene-viewer");
  });

  it("still renders 3D without ARCore, and only withholds the AR button", () => {
    // Gating the preview on the camera would throw away most of the value on
    // every budget handset.
    const result = resolvePresentation({
      platform: "android",
      model: model(),
      arCoreAvailable: false,
    });
    expect(result.inline.kind).toBe("glb");
    expect(result.ar.supported).toBe(false);
    expect(result.ar.reason).toMatch(/still view/i);
  });

  it("does not offer AR when ARCore availability was never probed", () => {
    // Undefined must not read as available: an AR button on a handset without
    // ARCore opens the Play Store instead of the camera.
    const result = resolvePresentation({ platform: "android", model: model() });
    expect(result.ar.supported).toBe(false);
  });

  it("ignores a missing USDZ entirely", () => {
    const result = resolvePresentation({
      platform: "android",
      model: model({ usdzUrl: null, usdzStatus: "pending" }),
      arCoreAvailable: true,
    });
    expect(result.inline.kind).toBe("glb");
    expect(result.ar.supported).toBe(true);
    expect(result.ar.blockedOnConversion).toBe(false);
  });
});

describe("resolvePresentation — web", () => {
  it("prefers WebXR where the browser reports support", () => {
    const result = resolvePresentation({
      platform: "web-other",
      model: model(),
      hasWebXr: true,
      isMobileWeb: true,
    });
    expect(result.ar.mode).toBe("webxr");
  });

  it("points desktop users at the QR code rather than claiming AR works", () => {
    const result = resolvePresentation({
      platform: "web-other",
      model: model(),
      hasWebXr: false,
      isMobileWeb: false,
    });
    expect(result.ar.supported).toBe(false);
    expect(result.ar.reason).toMatch(/QR code/i);
    // The model still renders — desktop is where a restaurant reviews it.
    expect(result.inline.kind).toBe("glb");
  });
});

describe("resolvePresentation — no model", () => {
  it("reports nothing renderable and no AR", () => {
    const result = resolvePresentation({ platform: "ios", model: null });
    expect(result.inline).toEqual({ kind: "none" });
    expect(result.ar.supported).toBe(false);
  });
});

describe("detectBrowserPlatform", () => {
  const UA = {
    ipadOs:
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15",
    macSafari:
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15",
    iphoneChrome:
      "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/126.0.6478.54 Mobile/15E148 Safari/604.1",
  };

  it("treats iPadOS as iOS despite its macOS user agent", () => {
    // iPadOS 13+ deliberately claims to be a Mac; touch points are the only
    // reliable signal, and the two UA strings here are byte-identical.
    expect(detectBrowserPlatform(UA.ipadOs, 5).isIos).toBe(true);
    expect(detectBrowserPlatform(UA.macSafari, 0).isIos).toBe(false);
  });

  it("recognises Chrome on iOS as iOS, since it is WebKit underneath", () => {
    expect(detectBrowserPlatform(UA.iphoneChrome, 5).isIos).toBe(true);
  });
});

describe("buildSceneViewerUrl", () => {
  it("defaults to non-resizable, so the dish lands at its real size", () => {
    const url = buildSceneViewerUrl({ glbUrl: "https://cdn.example/d.glb" });
    expect(url).toContain("resizable=false");
  });

  it("encodes the fallback URL, which is nested in the intent syntax", () => {
    // The intent string is semicolon-delimited, so an unencoded URL containing
    // one would truncate the intent rather than fail visibly.
    const url = buildSceneViewerUrl({
      glbUrl: "https://cdn.example/d.glb",
      fallbackUrl: "https://menu.example/dish?a=1;b=2",
    });
    expect(url).toContain(
      `S.browser_fallback_url=${encodeURIComponent("https://menu.example/dish?a=1;b=2")}`,
    );
    expect(url.endsWith(";end;")).toBe(true);
  });

  it("targets ARCore and ends the intent correctly", () => {
    const url = buildSceneViewerUrl({ glbUrl: "https://cdn.example/d.glb" });
    expect(url.startsWith("intent://arvr.google.com/scene-viewer/1.0?")).toBe(true);
    expect(url).toContain("package=com.google.ar.core");
    expect(url).toContain("mode=ar_preferred");
  });
});
