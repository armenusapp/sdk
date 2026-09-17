import type { TurboModule } from "react-native";
import { TurboModuleRegistry } from "react-native";

/**
 * The AR handoff, and the disk cache that feeds it.
 *
 * Deliberately small. Neither platform needs us to write an AR engine: iOS has
 * AR Quick Look (which is ARKit — plane detection, real-world scale, people
 * occlusion, contact shadows, drag and rotate gestures) and Android has Scene
 * Viewer (the same, on ARCore). Both take a file and a size. Reimplementing
 * either would be months of work to arrive somewhere worse, and would drift
 * from what the platform does everywhere else the user has seen AR.
 *
 * What the module DOES own is getting the file there. Quick Look will not read
 * a remote URL — it needs a local one — so a download has to happen either way,
 * and once it does the cache is free and is where the real performance win is:
 * the second view of a dish starts instantly instead of pulling 1–2 MB again.
 */
export interface Spec extends TurboModule {
  /**
   * Whether this handset can do AR at all.
   *
   * iOS: ARKit world-tracking support (A9 and later). Android: ARCore
   * installed and the device on Google's supported list. Must be called before
   * offering an AR button — an AR button on a handset without ARCore opens the
   * Play Store instead of the camera, which reads as a broken app.
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
   * Resolves when the viewer is dismissed, so a caller can restore its own UI.
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
