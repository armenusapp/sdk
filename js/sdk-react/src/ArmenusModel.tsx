"use client";

import {
  detectBrowserPlatform,
  resolvePresentation,
  type EmbedItem,
  type Presentation,
} from "@armenus/sdk-core";
import { useCallback, useEffect, useRef, useState, type ReactNode } from "react";
/*
 * Also augments React's JSX namespace so `<model-viewer>` is a known intrinsic
 * element — the import must be explicit, since relying on the file merely
 * being in the program breaks the moment a consumer compiles this differently.
 */
import type { ModelViewerElement } from "./model-viewer-element.js";

export interface ArmenusModelProps {
  /** The dish to render. Pass the result of `useArmenusItem`. */
  item: EmbedItem | null;
  /** Overrides the accessible description. Defaults to the dish name. */
  alt?: string;
  className?: string;
  /** Label on the AR button. */
  arLabel?: string;
  /** Rendered beneath the canvas, with the resolved AR state. */
  footer?: (presentation: Presentation) => ReactNode;
  /** Called when the user activates AR. For the host's own analytics. */
  onEnterAr?: (item: EmbedItem) => void;
}

type LoadState = "pending" | "ready" | "unavailable";

/**
 * Renders a dish in 3D, with AR where the browser supports it.
 *
 * Web only. `<model-viewer>` is used rather than raw Three.js because it is
 * the only thing that reaches all three browser AR mechanisms from one
 * element, and because it already solves the mobile WebGL pitfalls that
 * hand-rolled renderers get wrong: one renderer per page, correct glTF scene
 * traversal, normalised touch input, and context-loss recovery.
 *
 * The library is ~300 kB and is imported on mount, never at module scope — a
 * partner putting this in a product grid must not pay for it in their initial
 * bundle, where most of the viewport is text and prices.
 */
export function ArmenusModel({
  item,
  alt,
  className,
  arLabel = "View on your table",
  footer,
  onEnterAr,
}: ArmenusModelProps) {
  const [loadState, setLoadState] = useState<LoadState>("pending");
  const [modelError, setModelError] = useState(false);
  const [presentation, setPresentation] = useState<Presentation | null>(null);

  /* -- capability probe --------------------------------------------------- */

  useEffect(() => {
    let cancelled = false;

    const probe = async (): Promise<void> => {
      let hasWebXr = false;
      try {
        const xr = (
          navigator as Navigator & {
            xr?: { isSessionSupported: (mode: string) => Promise<boolean> };
          }
        ).xr;
        hasWebXr = (await xr?.isSessionSupported("immersive-ar")) ?? false;
      } catch {
        // A Permissions-Policy header can reject the probe outright, which is
        // a "no" rather than an error.
        hasWebXr = false;
      }
      if (cancelled) return;

      const platform = detectBrowserPlatform(
        navigator.userAgent,
        navigator.maxTouchPoints,
      );

      setPresentation(
        resolvePresentation({
          /*
           * Always "web-other", never "ios"/"android", even on an iPhone.
           * Those two mean the NATIVE SDKs, where the app owns the renderer
           * and the format rules bite. In a browser `<model-viewer>` reaches
           * Quick Look from a GLB by handing iOS the `ios-src` USDZ itself,
           * so the platform-specific format gating does not apply here and
           * applying it would blank out iPhone previews that work fine.
           */
          platform: "web-other",
          model: item?.model ?? null,
          hasWebXr,
          isMobileWeb: platform.isIos || platform.isAndroid,
        }),
      );
    };

    void probe();
    return () => {
      cancelled = true;
    };
  }, [item?.model]);

  /* -- model-viewer, loaded on mount -------------------------------------- */

  useEffect(() => {
    let cancelled = false;

    // Already registered by another instance on the page.
    if (globalThis.customElements?.get("model-viewer")) {
      setLoadState("ready");
      return;
    }

    import("@google/model-viewer")
      .then(() => {
        if (!cancelled) setLoadState("ready");
        return true;
      })
      .catch(() => {
        if (!cancelled) setLoadState("unavailable");
        return false;
      });

    return () => {
      cancelled = true;
    };
  }, []);

  /*
   * Kept so a host can drive AR itself — `viewerRef.current.activateAR()` is
   * the only way to open AR from the host's own button rather than ours, which
   * partners with an established design system invariably want.
   */
  const viewerRef = useRef<ModelViewerElement | null>(null);

  useEffect(() => {
    setModelError(false);
  }, [item?.model?.id, item?.model?.glbUrl]);

  const handleModelError = useCallback(() => setModelError(true), []);
  const handleEnterAr = useCallback(() => {
    if (item) onEnterAr?.(item);
  }, [item, onEnterAr]);

  const model = item?.model ?? null;
  const label = alt ?? item?.name ?? "3D model";
  const showViewer = loadState === "ready" && !modelError && model !== null;
  const view = model?.viewSettings;

  return (
    <div className={className ?? "armenus-viewer"} data-ar-mode={presentation?.ar.mode}>
      <div className="armenus-stage">
        {showViewer && view ? (
          <model-viewer
            ref={viewerRef}
            src={model.glbUrl}
            {...(model.usdzUrl ? { "ios-src": model.usdzUrl } : {})}
            {...(model.posterUrl ? { poster: model.posterUrl } : {})}
            alt={label}
            ar
            ar-modes="webxr scene-viewer quick-look"
            /*
             * "fixed", not "auto". The model has already been rescaled to its
             * real-world size by the pipeline, so the placed dish is the size
             * the dish actually is — which is the entire question a diner is
             * asking. "auto" hands that back to the user as a pinch gesture.
             */
            ar-scale="fixed"
            ar-placement="floor"
            camera-controls
            /*
             * "none", not "pan-y". With pan-y the page claims every vertical
             * drag, so dragging on the model scrolls the page instead of
             * tilting the dish — the first thing anyone tries. The stage is a
             * fixed-height box, so the page still scrolls from outside it.
             */
            touch-action="none"
            camera-orbit={view.cameraOrbit}
            camera-target={view.cameraTarget}
            field-of-view={view.fieldOfView}
            exposure={view.exposure}
            shadow-intensity={view.shadowIntensity}
            {...(view.autoRotate
              ? { "auto-rotate": true, "auto-rotate-delay": 1200 }
              : {})}
            loading="lazy"
            interaction-prompt="auto"
            onError={handleModelError}
            className="armenus-canvas"
          >
            {/*
              Our own button in model-viewer's slot rather than its default, so
              the label matches the host's copy. model-viewer still hides the
              slot entirely where AR cannot be activated, so this never renders
              as a dead control.
            */}
            <button
              slot="ar-button"
              className="armenus-ar-button"
              type="button"
              onClick={handleEnterAr}
            >
              {arLabel}
            </button>
          </model-viewer>
        ) : (
          <Placeholder
            posterUrl={model?.posterUrl ?? item?.imageUrl ?? null}
            alt={label}
            failed={loadState === "unavailable" || modelError || model === null}
            hasModel={model !== null}
          />
        )}
      </div>

      {/* Space is reserved while the probe runs, so resolving it shifts nothing. */}
      <p className="armenus-note" aria-live="polite">
        {presentation?.ar.reason ?? " "}
      </p>

      {presentation && footer?.(presentation)}
    </div>
  );
}

function Placeholder({
  posterUrl,
  alt,
  failed,
  hasModel,
}: {
  posterUrl: string | null;
  alt: string;
  failed: boolean;
  hasModel: boolean;
}) {
  if (failed) {
    // Not a live region: this is the final rendered content, not a transient
    // status, so it belongs in normal document order.
    return (
      <div className="armenus-placeholder">
        {posterUrl ? (
          <img src={posterUrl} alt={alt} className="armenus-poster" />
        ) : null}
        {!hasModel ? null : <p>This dish&rsquo;s 3D view could not be loaded.</p>}
      </div>
    );
  }

  /*
   * `<output>` is the semantic live region, so loading → loaded is announced
   * without a redundant role. The text matters: the engine is ~300 kB and the
   * mesh another 1–2 MB, so on mobile data there is a real wait, and a bare
   * shimmer reads as "broken" long before it reads as "loading".
   */
  return (
    <output className="armenus-placeholder" aria-label="Loading 3D view">
      {posterUrl ? (
        <img src={posterUrl} alt={alt} className="armenus-poster" />
      ) : (
        <div className="armenus-skeleton" aria-hidden="true" />
      )}
      <p>Loading 3D view…</p>
    </output>
  );
}
