import type { HostComponent, ViewProps } from "react-native";
import codegenNativeComponent from "react-native/Libraries/Utilities/codegenNativeComponent";
import type {
  DirectEventHandler,
  Double,
  WithDefault,
} from "react-native/Libraries/Types/CodegenTypes";

/**
 * The inline 3D preview — the model spinning in the card, before AR.
 *
 * This is the one part that genuinely needs a renderer, and it is why this
 * package has native code at all. Each platform gets its own, because there is
 * no format both of them read:
 *
 *   iOS      SCNView (SceneKit), loading USDZ. Cannot load glTF.
 *   Android  Filament via SceneView, loading GLB. Cannot load USDZ.
 *
 * So the `source` prop is a USDZ on one platform and a GLB on the other, and
 * `resolvePresentation()` in @armenus/sdk-core is what decides which — never
 * the call site. Getting it backwards yields a blank canvas and no error.
 */
export interface NativeProps extends ViewProps {
  /** Local path from `prefetch`, or a remote URL. Format is per-platform. */
  source: string;
  /** Shown while the mesh loads, and instead of it if loading fails. */
  posterUrl?: string;

  /* -- framing ----------------------------------------------------------- */
  /** Horizontal orbit in degrees. */
  cameraOrbitTheta?: WithDefault<Double, 0>;
  /** Vertical orbit in degrees. 90 is level with the dish. */
  cameraOrbitPhi?: WithDefault<Double, 75>;
  /** Distance as a multiple of the model's bounding radius. */
  cameraDistance?: WithDefault<Double, 1.05>;
  exposure?: WithDefault<Double, 1>;
  shadowIntensity?: WithDefault<Double, 1>;
  autoRotate?: WithDefault<boolean, true>;
  /**
   * Whether a drag rotates the model.
   *
   * Off inside a scrolling list: on a phone the gesture systems fight, and a
   * card that eats vertical drags makes the whole feed feel stuck.
   */
  interactionEnabled?: WithDefault<boolean, true>;

  onModelLoad?: DirectEventHandler<null>;
  onModelError?: DirectEventHandler<{ message: string }>;
}

export default codegenNativeComponent<NativeProps>(
  "ArmenusModelView",
) as HostComponent<NativeProps>;
