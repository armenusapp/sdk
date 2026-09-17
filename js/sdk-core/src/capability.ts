import type { EmbedModel } from "./types.js";

/**
 * What a given device can actually do with a given model.
 *
 * This is the one piece of logic every SDK needs and none of them should own,
 * because the rules are non-obvious in ways that produce dead buttons and
 * blank canvases when guessed at:
 *
 *   • There is no cross-platform AR API. Three mutually exclusive mechanisms
 *     exist — WebXR, Scene Viewer, AR Quick Look — and a device supports at
 *     most one.
 *   • There is no cross-platform model format. Quick Look and SceneKit read
 *     USDZ and cannot read GLB; Scene Viewer and Filament read GLB and cannot
 *     read USDZ. Every model therefore needs both files, and one of them is
 *     produced asynchronously after upload.
 *   • The consequence, which is easy to miss: on iOS a missing USDZ costs the
 *     inline preview too, not just AR. There is nothing an iPhone can render.
 *
 * Kept as a pure function of its inputs so every SDK can test it without a
 * device, and so the web and native paths cannot drift apart.
 */

export type Platform = "ios" | "android" | "web-other";

export type ArMode =
  /** In-page immersive session. Chrome/Edge on Android. */
  | "webxr"
  /** Android's system AR app, launched by intent. GLB. */
  | "scene-viewer"
  /** iOS/iPadOS system AR. USDZ only. Every iOS browser is WebKit. */
  | "quick-look"
  | "none";

/** Which asset the inline (non-AR) preview should load, if any. */
export type InlineSource =
  | { kind: "glb"; url: string }
  | { kind: "usdz"; url: string }
  /** No renderable mesh for this platform; show the still image. */
  | { kind: "poster"; url: string }
  /** Nothing at all to show. The caller renders its own empty state. */
  | { kind: "none" };

export interface PresentationInput {
  platform: Platform;
  model: EmbedModel | null;
  /**
   * Android only: whether ARCore is installed and supported on this handset.
   *
   * Must be probed natively (`ArCoreApk.checkAvailability`). Defaulting it to
   * true would put an AR button on every budget phone without ARCore, where
   * tapping it opens the Play Store instead of the camera.
   */
  arCoreAvailable?: boolean;
  /**
   * Web only: whether `navigator.xr.isSessionSupported('immersive-ar')`
   * resolved true.
   */
  hasWebXr?: boolean;
  /** Web only: needed to tell a phone from a desktop with no headset. */
  isMobileWeb?: boolean;
}

export interface ArAvailability {
  mode: ArMode;
  /** True when the user can actually place this model in their room. */
  supported: boolean;
  /** Why not. Null when it is supported. Written to be shown to a user. */
  reason: string | null;
  /**
   * True when the only thing missing is the USDZ conversion — a state that
   * resolves by itself in a minute or two.
   *
   * Separated from every other unsupported case because it is the one where
   * "check back shortly" is honest, and where a client may want to poll rather
   * than render a permanent-looking failure.
   */
  blockedOnConversion: boolean;
}

export interface Presentation {
  inline: InlineSource;
  ar: ArAvailability;
}

const UNSUPPORTED = (reason: string): ArAvailability => ({
  mode: "none",
  supported: false,
  reason,
  blockedOnConversion: false,
});

const SUPPORTED = (mode: ArMode): ArAvailability => ({
  mode,
  supported: true,
  reason: null,
  blockedOnConversion: false,
});

/**
 * Resolves what to render and whether AR is offerable.
 *
 * Every SDK funnels through this. A platform that returns `inline.kind` it
 * cannot load is a bug in this function, not in the renderer.
 */
export function resolvePresentation(input: PresentationInput): Presentation {
  const { platform, model } = input;

  if (!model) {
    return {
      inline: { kind: "none" },
      ar: UNSUPPORTED("This dish does not have a 3D model yet."),
    };
  }

  const poster: InlineSource = model.posterUrl
    ? { kind: "poster", url: model.posterUrl }
    : { kind: "none" };

  switch (platform) {
    /* -- iOS: USDZ or nothing ------------------------------------------- */
    case "ios": {
      if (!model.usdzUrl) {
        /*
         * The wide gate. SceneKit cannot open a GLB, so with no USDZ an iPhone
         * has no mesh to draw at all — this is not just the AR button going
         * missing, it is the preview falling back to a photograph.
         */
        const failed = model.usdzStatus === "failed";
        return {
          inline: poster,
          ar: failed
            ? UNSUPPORTED("The AR version of this dish is unavailable.")
            : {
                mode: "none",
                supported: false,
                reason: "The AR version of this dish is still being prepared.",
                blockedOnConversion: true,
              },
        };
      }

      return {
        inline: { kind: "usdz", url: model.usdzUrl },
        ar: SUPPORTED("quick-look"),
      };
    }

    /* -- Android: GLB inline, Scene Viewer for AR ------------------------ */
    case "android": {
      return {
        // Filament renders the GLB regardless of ARCore — a handset with no
        // AR support still gets a model it can spin, which is most of the
        // value and all of the reason not to gate the preview on the camera.
        inline: { kind: "glb", url: model.glbUrl },
        ar: input.arCoreAvailable
          ? SUPPORTED("scene-viewer")
          : UNSUPPORTED(
              "This device does not support AR. You can still view the dish in 3D.",
            ),
      };
    }

    /* -- Web: model-viewer picks its own path ---------------------------- */
    case "web-other": {
      // Browsers always render the GLB inline; only the AR path varies.
      const inline: InlineSource = { kind: "glb", url: model.glbUrl };

      if (input.hasWebXr) return { inline, ar: SUPPORTED("webxr") };

      if (!input.isMobileWeb) {
        return {
          inline,
          ar: UNSUPPORTED("Scan the QR code with your phone to view this dish in AR."),
        };
      }

      return {
        inline,
        ar: UNSUPPORTED(
          "This browser does not support AR. Open the page in Chrome or Safari to place the dish on your table.",
        ),
      };
    }
  }
}

/* ------------------------------------------------------------------------ */
/* Browser detection                                                         */
/* ------------------------------------------------------------------------ */

export interface BrowserPlatformInput {
  userAgent: string;
  /** `navigator.maxTouchPoints` — the only reliable iPadOS tell. */
  maxTouchPoints: number;
}

export interface BrowserPlatform {
  isIos: boolean;
  isAndroid: boolean;
  isFirefox: boolean;
  isChromium: boolean;
  isSafari: boolean;
  isIpadOs: boolean;
}

export function detectBrowserPlatform(
  userAgent: string,
  maxTouchPoints: number,
): BrowserPlatform {
  const ua = userAgent;

  // iPadOS 13+ reports a macOS user agent; touch points are the reliable tell.
  const isIpadOs = /Macintosh/i.test(ua) && maxTouchPoints > 1;
  const isIos = /iPhone|iPad|iPod/i.test(ua) || isIpadOs;
  const isAndroid = /Android/i.test(ua);
  const isFirefox = /Firefox\/|FxiOS/i.test(ua);
  // Chrome on iOS is CriOS and is still WebKit underneath.
  const isChromium = /Chrome\/|CriOS|Chromium|Edg\//i.test(ua) && !/OPR\//i.test(ua);
  const isSafari = /Safari\//i.test(ua) && !/Chrome\/|Chromium|Edg\//i.test(ua);

  return { isIos, isAndroid, isFirefox, isChromium, isSafari, isIpadOs };
}

/* ------------------------------------------------------------------------ */
/* Scene Viewer                                                              */
/* ------------------------------------------------------------------------ */

export interface SceneViewerOptions {
  glbUrl: string;
  title?: string;
  /**
   * Where the browser should land if Scene Viewer is not installed. Android
   * intent URLs carry their own fallback and silently do nothing without one.
   */
  fallbackUrl?: string;
  /**
   * Whether the user may pinch-scale the model.
   *
   * Defaults to false, and that default is the whole point of the feature.
   * The model is already scaled to `physicalSizeM`, so it lands on the table
   * at the size the dish actually is — which is the question a diner is asking.
   * Letting them resize it turns an answer back into a guess.
   */
  resizable?: boolean;
}

/**
 * Builds the Android intent URL that launches Scene Viewer.
 *
 * Shared between the web SDK (which sets it as an href) and the native Android
 * SDK (which fires it as an Intent), so the parameters cannot diverge between
 * a partner's website and their app.
 */
export function buildSceneViewerUrl(options: SceneViewerOptions): string {
  const params = new URLSearchParams({
    file: options.glbUrl,
    mode: "ar_preferred",
    resizable: options.resizable ? "true" : "false",
  });
  if (options.title) params.set("title", options.title);

  const intent = `intent://arvr.google.com/scene-viewer/1.0?${params.toString()}#Intent;scheme=https;package=com.google.ar.core;action=android.intent.action.VIEW`;

  // `S.browser_fallback_url` is what stops the intent failing silently on a
  // device without Scene Viewer; the value must be encoded because it is a URL
  // nested inside the intent's own semicolon-delimited syntax.
  const fallback = options.fallbackUrl
    ? `;S.browser_fallback_url=${encodeURIComponent(options.fallbackUrl)}`
    : "";

  return `${intent}${fallback};end;`;
}
