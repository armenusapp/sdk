/**
 * React bindings.
 *
 * A separate entry point rather than part of the main export, so that the
 * promise the main entry makes — zero dependencies — stays true. React is a
 * peer here and is only reachable through `@armenus/sdk-core/react`; a Vue,
 * Svelte or plain-JS consumer importing the client never resolves it.
 *
 * Both `@armenus/sdk-react` and `@armenus/sdk-react-native` re-export this
 * module. The hooks are pure React and touch no DOM and no native module, so
 * there is exactly one implementation rather than two that drift.
 */
export {
  ArmenusProvider,
  useArmenusClient,
  type ArmenusProviderProps,
} from "./provider.js";
export {
  useArmenusConfig,
  useArmenusItem,
  useArmenusItemByRef,
  useArmenusItems,
  type AsyncState,
} from "./hooks.js";
