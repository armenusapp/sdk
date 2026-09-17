/**
 * One error type, carrying the API's own error code.
 *
 * Integrators need to branch on *why* a call failed far more often than they
 * need a stack trace: a revoked key and a dish that has no model yet are both
 * "the model did not appear", and they call for opposite responses — page the
 * on-call engineer versus render the photo and move on.
 */
export class ArmenusError extends Error {
  /** HTTP status, or 0 when the request never reached the API. */
  readonly status: number;
  /** The API's machine-readable code, e.g. "not_found", "forbidden". */
  readonly code: string;
  readonly details?: unknown;

  constructor(status: number, code: string, message: string, details?: unknown) {
    super(message);
    this.name = "ArmenusError";
    this.status = status;
    this.code = code;
    this.details = details;
  }

  /**
   * True when retrying could plausibly work: a network blip, a rate limit, or
   * a server fault. False for anything the caller must fix first — a bad key,
   * a wrong id — where retrying is just a slower failure.
   */
  get isRetryable(): boolean {
    return this.status === 0 || this.status === 429 || this.status >= 500;
  }

  /**
   * True when the key itself is the problem. Worth separating because it is
   * the one failure an integrator should surface loudly in their own logs
   * rather than degrading past — every dish will fail, not just this one.
   */
  get isAuthError(): boolean {
    return this.status === 401 || this.status === 403;
  }
}
