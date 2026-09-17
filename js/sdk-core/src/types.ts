/**
 * The wire shape of the embed API.
 *
 * Hand-written rather than imported from `@armenus/contracts`, which is the
 * one place in this repo where duplicating a type is the right call. Contracts
 * is Zod, Zod is a runtime dependency, and this package is installed by people
 * who are not us — shipping a schema validator into a customer's app bundle to
 * describe responses we control, and which their code never validates, is
 * weight they did not ask for. Zero dependencies is the product here.
 *
 * The duplication is not left to vigilance: `conformance.test-d.ts` asserts
 * these types are structurally identical to the contract types at build time,
 * so a field added to one and not the other fails CI rather than reaching a
 * partner as a runtime undefined.
 */

/** USDZ readiness. Gates iOS entirely — see `EmbedModel.usdzUrl`. */
export type UsdzStatus = "pending" | "processing" | "ready" | "failed";

/** Camera framing, passed through to whichever renderer the platform uses. */
export interface ModelViewSettings {
  /** "theta phi radius", e.g. "0deg 75deg 105%". */
  cameraOrbit: string;
  /** "x y z", or "auto auto auto". */
  cameraTarget: string;
  /** "auto" or an angle like "30deg". */
  fieldOfView: string;
  exposure: number;
  shadowIntensity: number;
  autoRotate: boolean;
  /**
   * Multiplier applied to the model before AR placement.
   *
   * Distinct from `EmbedModel.physicalSizeM`, and the two are easy to
   * conflate. `physicalSizeM` is a measurement — how big the dish is. This is
   * a correction a restaurant applies when the measurement is right but the
   * placed result still reads wrong. Native clients must apply both.
   */
  arScale: number;
}

export interface EmbedModel {
  id: string;
  /** Android inline (Filament), Scene Viewer AR, and every browser path. */
  glbUrl: string;
  /**
   * iOS inline (SceneKit) and Quick Look AR. Null until conversion finishes.
   *
   * On iOS this gates the inline preview as well as AR: SceneKit cannot load
   * a GLB, so an iPhone with no USDZ has nothing to render and falls back to
   * `posterUrl`.
   */
  usdzUrl: string | null;
  usdzStatus: UsdzStatus;
  /** Shown while the mesh downloads, and wherever no mesh can be rendered. */
  posterUrl: string | null;
  /** Longest side in metres. Required for AR placement at believable scale. */
  physicalSizeM: number;
  /** Optimised GLB size. Null on rows predating the measurement. */
  glbBytes: number | null;
  viewSettings: ModelViewSettings;
}

export interface EmbedMerchant {
  id: string;
  slug: string;
  name: string;
  currency: string;
  locale: string;
}

export interface EmbedItem {
  id: string;
  slug: string;
  /** The host app's own identifier, when it set one. */
  externalRef: string | null;
  name: string;
  description: string | null;
  priceCents: number;
  tags: string[];
  imageUrl: string | null;
  isAvailable: boolean;
  merchant: EmbedMerchant;
  /** Null when the dish has no model, or has one that is not ready yet. */
  model: EmbedModel | null;
}

export interface EmbedItemList {
  items: EmbedItem[];
  /** Opaque; changes whenever the list does. Cache keys derive from it. */
  version: string;
}

export interface EmbedConfig {
  scope: "partner" | "restaurant";
  ownerName: string;
  merchants: EmbedMerchant[];
}
