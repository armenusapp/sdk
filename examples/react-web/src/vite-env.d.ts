/// <reference types="vite/client" />

/**
 * Typed so `import.meta.env.VITE_ARMENUS_KEY` is `string | undefined` rather
 * than `any` — which is what makes the "did you set the key?" branch in App.tsx
 * something the compiler enforces instead of something we hope we remembered.
 */
interface ImportMetaEnv {
  readonly VITE_ARMENUS_KEY?: string;
  readonly VITE_ARMENUS_BASE_URL?: string;
  readonly VITE_ARMENUS_MERCHANT_ID?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
