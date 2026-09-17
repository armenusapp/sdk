import {
  resolvePresentation,
  type EmbedItem,
  type Presentation,
} from "@armenus/sdk-core";
import { useCallback, useEffect, useMemo, useState, type ReactNode } from "react";
import {
  ActivityIndicator,
  Image,
  Platform,
  Pressable,
  StyleSheet,
  Text,
  View,
  type StyleProp,
  type ViewStyle,
} from "react-native";
import NativeArmenusAr from "./specs/NativeArmenusAr.js";
import ArmenusModelView from "./specs/ArmenusModelViewNativeComponent.js";

export interface ArmenusModelProps {
  /** The dish to render. Pass the result of `useArmenusItem`. */
  item: EmbedItem | null;
  style?: StyleProp<ViewStyle>;
  arLabel?: string;
  /**
   * Whether a drag rotates the model.
   *
   * Pass false inside a FlatList. On a phone the two gesture systems fight,
   * and a card that swallows vertical drags makes the whole feed feel stuck —
   * a worse trade than losing the spin on a card the user is scrolling past.
   */
  interactionEnabled?: boolean;
  /** Rendered beneath the canvas, with the resolved capability state. */
  footer?: (presentation: Presentation) => ReactNode;
  onEnterAr?: (item: EmbedItem) => void;
  onError?: (message: string) => void;
}

/**
 * A dish in 3D, with AR where the handset supports it.
 *
 * Fully native on both platforms — SceneKit and Filament for the inline
 * preview, AR Quick Look and Scene Viewer for placement. No WebView is
 * involved, which is the point: a WebView costs a second renderer, its own
 * process, JavaScript-bridged touch handling and a visible pop-in, and buys
 * nothing here because both platforms already expose the AR viewer natively.
 */
export function ArmenusModel({
  item,
  style,
  arLabel = "View on your table",
  interactionEnabled = true,
  footer,
  onEnterAr,
  onError,
}: ArmenusModelProps) {
  const [arAvailable, setArAvailable] = useState(false);
  const [loaded, setLoaded] = useState(false);
  const [failed, setFailed] = useState(false);
  const [presenting, setPresenting] = useState(false);

  /* -- device capability, probed once ------------------------------------- */

  useEffect(() => {
    let cancelled = false;
    NativeArmenusAr.isArAvailable()
      .then((available) => {
        if (!cancelled) setArAvailable(available);
        return available;
      })
      .catch(() => {
        // A failed probe is a "no". Offering AR on a handset that cannot do it
        // sends the user to the Play Store, which reads as a broken app.
        if (!cancelled) setArAvailable(false);
      });
    return () => {
      cancelled = true;
    };
  }, []);

  const presentation = useMemo(
    () =>
      resolvePresentation({
        platform: Platform.OS === "ios" ? "ios" : "android",
        model: item?.model ?? null,
        arCoreAvailable: arAvailable,
      }),
    [item?.model, arAvailable],
  );

  /*
   * iOS is the case that catches people out: with no USDZ there is no mesh an
   * iPhone can draw at all, so this is a poster, not a GLB. `resolvePresentation`
   * has already decided; the component must not second-guess it by reaching
   * for `model.glbUrl` on a platform that cannot open one.
   */
  const inline = presentation.inline;
  const arUrl = Platform.OS === "ios" ? item?.model?.usdzUrl : item?.model?.glbUrl;

  /* -- prefetch ----------------------------------------------------------- */

  useEffect(() => {
    if (!arUrl || !presentation.ar.supported) return;
    /*
     * Warm the cache as soon as we know AR is offerable, rather than on tap.
     * Quick Look needs a local file either way, so this download is not
     * optional — only its timing is, and doing it here is the difference
     * between an AR button that opens instantly and one that stalls for two
     * seconds while the user wonders whether the tap registered.
     */
    NativeArmenusAr.prefetch(arUrl).catch(() => undefined);
  }, [arUrl, presentation.ar.supported]);

  /* -- AR ----------------------------------------------------------------- */

  const enterAr = useCallback(() => {
    if (!item || !arUrl || presenting) return;
    setPresenting(true);
    onEnterAr?.(item);

    NativeArmenusAr.presentAr({
      url: arUrl,
      title: item.name,
      // Life-size and fixed. The model has already been scaled to the dish's
      // real dimensions, which is the whole question being asked.
      allowScaling: false,
    })
      .catch((error: unknown) => onError?.(String(error)))
      .finally(() => setPresenting(false));
  }, [item, arUrl, presenting, onEnterAr, onError]);

  const handleLoad = useCallback(() => setLoaded(true), []);
  const handleError = useCallback(
    (event: { nativeEvent: { message: string } }) => {
      setFailed(true);
      onError?.(event.nativeEvent.message);
    },
    [onError],
  );
  // Memoised because a new array or object here re-renders the native view on
  // every parent render — the exact cost this SDK exists to avoid.
  const containerStyle = useMemo(() => [styles.container, style], [style]);

  const view = item?.model?.viewSettings;
  const canRenderMesh =
    (inline.kind === "glb" || inline.kind === "usdz") && !failed && view;

  return (
    <View style={containerStyle}>
      <View style={styles.stage}>
        {canRenderMesh ? (
          <ArmenusModelView
            style={StyleSheet.absoluteFill}
            source={inline.url}
            {...(item?.model?.posterUrl ? { posterUrl: item.model.posterUrl } : {})}
            cameraOrbitTheta={parseDeg(view.cameraOrbit, 0, 0)}
            cameraOrbitPhi={parseDeg(view.cameraOrbit, 1, 75)}
            exposure={view.exposure}
            shadowIntensity={view.shadowIntensity}
            autoRotate={view.autoRotate}
            interactionEnabled={interactionEnabled}
            onModelLoad={handleLoad}
            onModelError={handleError}
          />
        ) : null}

        {/* Poster stays mounted beneath the canvas until the mesh reports in,
            so there is never a blank frame between the two. */}
        {!loaded || !canRenderMesh ? (
          <Poster
            url={
              (inline.kind === "poster" ? inline.url : null) ??
              item?.model?.posterUrl ??
              item?.imageUrl ??
              null
            }
            showSpinner={Boolean(canRenderMesh) && !loaded}
          />
        ) : null}

        {presentation.ar.supported ? (
          <Pressable
            style={styles.arButton}
            onPress={enterAr}
            disabled={presenting}
            accessibilityRole="button"
            accessibilityLabel={arLabel}
          >
            <Text style={styles.arButtonText}>{arLabel}</Text>
          </Pressable>
        ) : null}
      </View>

      {presentation.ar.reason ? (
        <Text style={styles.note}>{presentation.ar.reason}</Text>
      ) : null}

      {footer?.(presentation)}
    </View>
  );
}

function Poster({ url, showSpinner }: { url: string | null; showSpinner: boolean }) {
  // Memoised: this sits behind the canvas and re-renders on every parent
  // render, and a fresh `source` object makes RN re-resolve the image each time.
  const source = useMemo(() => (url ? { uri: url } : null), [url]);

  return (
    <View style={posterStyle}>
      {source ? (
        <Image source={source} style={styles.posterImage} resizeMode="contain" />
      ) : null}
      {showSpinner ? <ActivityIndicator style={styles.spinner} /> : null}
    </View>
  );
}

/**
 * Pulls one angle out of a model-viewer `camera-orbit` string.
 *
 * The wire format is model-viewer's ("0deg 75deg 105%") because the same
 * framing has to drive the web SDK verbatim, and a restaurant sets it once for
 * all platforms. The native renderers take numbers, so it is parsed here
 * rather than stored twice and allowed to disagree.
 */
function parseDeg(orbit: string, index: number, fallback: number): number {
  const part = orbit.trim().split(/\s+/)[index];
  if (!part) return fallback;
  const value = Number.parseFloat(part);
  if (Number.isNaN(value)) return fallback;
  // Radians are legal in the format too, and are not the unit we return.
  return part.endsWith("rad") ? (value * 180) / Math.PI : value;
}

const styles = StyleSheet.create({
  container: { width: "100%" },
  stage: {
    width: "100%",
    aspectRatio: 1,
    borderRadius: 14,
    overflow: "hidden",
    backgroundColor: "#f4f2f3",
  },
  poster: { alignItems: "center", justifyContent: "center" },
  posterImage: { width: "100%", height: "100%" },
  spinner: { position: "absolute" },
  arButton: {
    position: "absolute",
    bottom: 16,
    alignSelf: "center",
    // 44pt minimum touch target.
    minHeight: 44,
    paddingHorizontal: 20,
    justifyContent: "center",
    borderRadius: 999,
    backgroundColor: "#dc2626",
  },
  arButtonText: { color: "#fff", fontSize: 15, fontWeight: "600" },
  note: {
    marginTop: 10,
    fontSize: 13,
    lineHeight: 20,
    color: "#6b5555",
    textAlign: "center",
  },
});

/** Hoisted, so the array identity is stable across every render. */
const posterStyle = [StyleSheet.absoluteFill, styles.poster];
