package app.armenus.sdk

/**
 * One exception type, carrying the API's own error code.
 *
 * Integrators need to branch on *why* a call failed far more often than they
 * need a stack trace: a revoked key and a dish that has no model yet are both
 * "the model did not appear", and they call for opposite responses.
 */
class ArmenusException(
  /** HTTP status, or 0 when the request never reached the API. */
  val status: Int,
  /** The API's machine-readable code, e.g. `not_found`, `forbidden`. */
  val code: String,
  message: String,
  /** The API's `details` field as raw JSON, when it sent one. */
  val details: String? = null,
  cause: Throwable? = null,
) : Exception(message, cause) {

  /**
   * True when retrying could plausibly work: a network blip, a rate limit or a
   * server fault. False for anything the caller must fix first.
   */
  val isRetryable: Boolean
    get() = status == 0 || status == 429 || status >= 500

  /**
   * True when the key itself is the problem. Worth separating because it is
   * the one failure to surface loudly rather than degrade past: every dish
   * will fail, not just this one.
   */
  val isAuthError: Boolean
    get() = status == 401 || status == 403
}
