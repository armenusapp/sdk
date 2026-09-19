export { ArmenusModel, type ArmenusModelProps } from "./ArmenusModel";

/** Cache and AR control, for hosts that want to manage either explicitly. */
export { default as ArmenusNative } from "./specs/NativeArmenusAr";

/* Shared React bindings — one implementation, common with the web SDK. */
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

export {
  ArmenusClient,
  ArmenusError,
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
  type Presentation,
  type UsdzStatus,
} from "@armenus/sdk-core";
