export { ArmenusModel, type ArmenusModelProps } from "./ArmenusModel.js";
/*
 * The provider and hooks are pure React — no DOM, no native module — so they
 * live in sdk-core and are re-exported here rather than reimplemented. A
 * consumer imports everything from this package and never learns that.
 */
export {
  ArmenusProvider,
  useArmenusClient,
  useArmenusConfig,
  useArmenusItem,
  useArmenusItemByRef,
  useArmenusItems,
  type ArmenusProviderProps,
  type AsyncState,
} from "@armenus/sdk-core/react";

/*
 * Re-exported so a consumer never has to add @armenus/sdk-core to their
 * package.json to name a type in their own code — the commonest reason an SDK
 * ends up with a version skew between two of its own packages.
 */
export {
  ArmenusClient,
  ArmenusError,
  buildSceneViewerUrl,
  detectBrowserPlatform,
  resolvePresentation,
  type ArAvailability,
  type ArMode,
  type ArmenusClientOptions,
  type EmbedConfig,
  type EmbedItem,
  type EmbedItemList,
  type EmbedMerchant,
  type EmbedModel,
  type InlineSource,
  type ModelViewSettings,
  type Platform,
  type Presentation,
  type UsdzStatus,
} from "@armenus/sdk-core";
