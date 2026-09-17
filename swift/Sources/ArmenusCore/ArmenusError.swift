import Foundation

/// One error type, carrying the API's own error code.
///
/// Integrators need to branch on *why* a call failed far more often than they
/// need a stack trace: a revoked key and a dish that has no model yet are both
/// "the model did not appear", and they call for opposite responses.
public struct ArmenusError: Error, LocalizedError, Equatable, Sendable {
  /// HTTP status, or 0 when the request never reached the API.
  public let status: Int
  /// The API's machine-readable code, e.g. `"not_found"`, `"forbidden"`.
  public let code: String
  public let message: String
  /// The API's `details` field as raw JSON, when it sent one.
  public let details: String?

  public init(status: Int, code: String, message: String, details: String? = nil) {
    self.status = status
    self.code = code
    self.message = message
    self.details = details
  }

  public var errorDescription: String? { message }

  /// True when retrying could plausibly work: a network blip, a rate limit or
  /// a server fault. False for anything the caller must fix first.
  public var isRetryable: Bool {
    status == 0 || status == 429 || status >= 500
  }

  /// True when the key itself is the problem. Worth separating because it is
  /// the one failure to surface loudly rather than degrade past: every dish
  /// will fail, not just this one.
  public var isAuthError: Bool {
    status == 401 || status == 403
  }
}
