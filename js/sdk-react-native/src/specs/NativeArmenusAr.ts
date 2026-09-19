import type { TurboModule } from "react-native";
import { TurboModuleRegistry } from "react-native";

/** Opens the system AR viewer and manages downloaded model files. */
export interface Spec extends TurboModule {
  /**
   * Whether this handset can do AR at all.
   *
   * iOS checks AR world-tracking support. Android checks whether the system
   * Scene Viewer is installed and can handle the handoff. Scene Viewer may
   * show its 3D fallback if AR is unavailable.
   */
  isArAvailable(): Promise<boolean>;

  /**
   * Downloads a model and returns a local file path, from cache when possible.
   *
   * Exposed rather than kept private because the caller knows things we do
   * not: a product grid can warm the cache for the dishes about to scroll into
   * view, which is the difference between an AR button that opens instantly
   * and one that stalls for two seconds on first tap.
   */
  prefetch(url: string): Promise<string>;

  /**
   * Presents the system AR viewer.
   *
   * `physicalSizeM` and `arScale` both apply and are different things: the
   * first is how big the dish is, the second a correction the restaurant set.
   * Resolves when dismissed on iOS, or after launching the viewer on Android.
   */
  presentAr(options: {
    /** USDZ on iOS, GLB on Android. The caller picks; the platforms differ. */
    url: string;
    title: string;
    /**
     * Whether the user may pinch-scale the placed model.
     *
     * Defaults false at the call sites for a reason worth restating: the model
     * is already scaled to life size, which is the entire question the diner
     * is asking. Letting them resize it turns the answer back into a guess.
     */
    allowScaling: boolean;
  }): Promise<void>;

  /** Bytes currently held on disk, so a host app can show and manage it. */
  cacheSize(): Promise<number>;
  clearCache(): Promise<void>;
}

export default TurboModuleRegistry.getEnforcing<Spec>("ArmenusAr");
