import type { CSSProperties, ReactNode, RefObject } from "react";

/**
 * `<model-viewer>` is a custom element, so JSX needs to be told about it.
 * React 19 passes unknown props on custom elements straight through as
 * attributes, which is exactly the behaviour model-viewer expects.
 *
 * Only the attributes this app actually sets are declared — an exhaustive
 * mirror of model-viewer's API would rot with every release.
 */
export interface ModelViewerAttributes {
  ref?: RefObject<ModelViewerElement | null>;
  key?: string | number;
  class?: string;
  className?: string;
  style?: CSSProperties;
  slot?: string;
  /** Slotted content: the custom AR button, poster and progress bar. */
  children?: ReactNode;

  /** GLB. Drives on-screen 3D, WebXR and Scene Viewer. */
  src?: string;
  /** USDZ. The only format iOS AR Quick Look accepts. */
  "ios-src"?: string;
  /** Required for screen readers; model-viewer renders it into its shadow DOM. */
  alt?: string;
  poster?: string;

  ar?: boolean;
  "ar-modes"?: string;
  "ar-scale"?: "auto" | "fixed";
  "ar-placement"?: "floor" | "wall";

  "camera-controls"?: boolean;
  "camera-orbit"?: string;
  "camera-target"?: string;
  "field-of-view"?: string;
  "min-camera-orbit"?: string;
  "max-camera-orbit"?: string;
  "interaction-prompt"?: "auto" | "none";
  "touch-action"?: "pan-y" | "pan-x" | "none";
  "disable-zoom"?: boolean;

  "auto-rotate"?: boolean;
  "auto-rotate-delay"?: number;
  "rotation-per-second"?: string;

  /* -- glTF animation ---------------------------------------------------- */
  /** Which clip to play. Omit and model-viewer picks the first one. */
  "animation-name"?: string;
  /** Off by default here: clips driven by a control must not also loop. */
  autoplay?: boolean;
  "animation-crossfade-duration"?: number;

  exposure?: number;
  "shadow-intensity"?: number;
  "shadow-softness"?: number;
  "environment-image"?: string;
  "tone-mapping"?: string;

  loading?: "auto" | "lazy" | "eager";
  reveal?: "auto" | "manual";

  onLoad?: (event: Event) => void;
  onError?: (event: Event) => void;
}

/** The subset of the element's imperative API this package uses. */
export interface ModelViewerElement extends HTMLElement {
  canActivateAR: boolean;
  activateAR: () => Promise<void>;
  cameraOrbit: string;
  fieldOfView: string;
  getCameraOrbit: () => {
    theta: number;
    phi: number;
    radius: number;
    toString: () => string;
  };
  resetTurntableRotation: (radians?: number) => void;
  toDataURL: (type?: string, encoderOptions?: number) => string;

  /* -- glTF animation ---------------------------------------------------- */
  /** Names of every clip in the loaded model. */
  readonly availableAnimations: string[];
  animationName?: string;
  /** Playback rate. Negative runs the clip backwards, which is how a
      one-directional "open" clip also serves as "close". */
  timeScale: number;
  currentTime: number;
  readonly duration: number;
  readonly paused: boolean;
  play: (options?: { repetitions?: number; pingpong?: boolean }) => void;
  pause: () => void;
}

declare module "react" {
  namespace JSX {
    interface IntrinsicElements {
      "model-viewer": ModelViewerAttributes;
    }
  }
}
