import Foundation

/// Client for the Armenus embed API.
///
/// Read-only, because the credential it holds is public. Anything that costs
/// money or changes data needs the secret partner key and a server to hold it.
public final class ArmenusClient: @unchecked Sendable {
  public static let defaultBaseURL = URL(string: "https://api.armenus.app/v1")!

  public let baseURL: URL
  private let key: String
  private let timeout: TimeInterval
  private let retries: Int
  private let session: URLSession
  private let decoder = JSONDecoder()

  /// - Parameters:
  ///   - publishableKey: A `pk_` key. Safe to ship in an app by construction.
  ///   - baseURL: Override for staging or self-hosted deployments.
  ///   - timeout: Per-attempt ceiling. The default in every HTTP stack is "wait
  ///     forever", and the caller here is usually a phone rendering a card.
  ///   - retries: Attempts for retryable failures, including the first. Only
  ///     idempotent reads exist in this API, so retrying is always safe here.
  /// - Throws: ``ArmenusError`` with code `invalid_key` for anything that is
  ///   not a publishable key. Thrown at construction on purpose: the common
  ///   integration mistake is pasting the secret `ak_` key into an app, which
  ///   would work all the way into production.
  public init(
    publishableKey: String,
    baseURL: URL = ArmenusClient.defaultBaseURL,
    timeout: TimeInterval = 8,
    retries: Int = 2,
    session: URLSession = .shared
  ) throws {
    guard publishableKey.hasPrefix("pk_") else {
      throw ArmenusError(
        status: 0,
        code: "invalid_key",
        message: publishableKey.hasPrefix("ak_")
          ? "That is a secret API key. Never ship an ak_ key in client code. Use a publishable pk_ key."
          : "A publishable key (pk_...) is required."
      )
    }
    self.key = publishableKey
    self.baseURL = baseURL
    self.timeout = timeout
    self.retries = max(1, retries)
    self.session = session
  }

  /// What this key can see. Call it once at startup so a revoked or mistyped
  /// key fails here rather than presenting as an empty catalogue.
  public func config() async throws -> EmbedConfig {
    try await request(path: "/embed/config")
  }

  /// One dish, by Armenus id.
  public func item(_ id: String) async throws -> EmbedItem {
    try await request(path: "/embed/items/\(encode(id))")
  }

  /// One dish, by the host app's own identifier, so it never has to store ours.
  public func item(merchantID: String, externalRef: String) async throws -> EmbedItem {
    try await request(
      path: "/embed/merchants/\(encode(merchantID))/items/by-ref/\(encode(externalRef))"
    )
  }

  /// Every dish on one merchant. `withModel` filters to dishes with a ready,
  /// published model and paginates correctly against that filter.
  public func items(
    merchantID: String,
    withModel: Bool = false,
    limit: Int? = nil,
    offset: Int? = nil
  ) async throws -> EmbedItemList {
    var query: [URLQueryItem] = []
    if withModel { query.append(URLQueryItem(name: "withModel", value: "true")) }
    if let limit { query.append(URLQueryItem(name: "limit", value: String(limit))) }
    if let offset { query.append(URLQueryItem(name: "offset", value: String(offset))) }
    return try await request(path: "/embed/merchants/\(encode(merchantID))/items", query: query)
  }

  /// Up to 50 dishes in one request. A grid needs twenty models at once, and
  /// twenty round trips over restaurant wifi is the difference between a grid
  /// that pops in and one that trickles.
  public func items(ids: [String]) async throws -> EmbedItemList {
    if ids.isEmpty {
      // Short-circuited rather than sent: the API rejects an empty `ids` as
      // malformed, and an empty list is an ordinary state for a grid that has
      // not resolved its rows yet.
      return EmbedItemList(items: [], version: "")
    }
    return try await request(
      path: "/embed/items",
      query: [URLQueryItem(name: "ids", value: ids.joined(separator: ","))]
    )
  }

  // MARK: - Transport

  private func request<T: Decodable>(path: String, query: [URLQueryItem] = []) async throws -> T {
    var lastError: ArmenusError?

    for attempt in 0..<retries {
      do {
        return try await self.attempt(path: path, query: query)
      } catch let failure as ArmenusError {
        // A cancelled task is not a failure to retry around: the screen it was
        // feeding is gone.
        if Task.isCancelled { throw failure }
        if !failure.isRetryable { throw failure }
        lastError = failure

        if attempt < retries - 1 {
          // Exponential and jittered. Without jitter a restaurant full of
          // phones that failed on the same blip retries in lockstep.
          let backoff = 0.2 * pow(2, Double(attempt))
          let delay = backoff + Double.random(in: 0...backoff)
          try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
      }
    }

    throw lastError ?? ArmenusError(status: 0, code: "network_error", message: "Request failed")
  }

  private func attempt<T: Decodable>(path: String, query: [URLQueryItem]) async throws -> T {
    var request = URLRequest(url: url(path: path, query: query))
    request.httpMethod = "GET"
    request.timeoutInterval = timeout
    request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Accept")

    let data: Data
    let response: URLResponse
    do {
      (data, response) = try await session.data(for: request)
    } catch let error as URLError where error.code == .timedOut {
      throw ArmenusError(
        status: 0,
        code: "timeout",
        message: "Request timed out after \(Int(timeout * 1000))ms"
      )
    } catch {
      throw ArmenusError(status: 0, code: "network_error", message: error.localizedDescription)
    }

    guard let http = response as? HTTPURLResponse else {
      throw ArmenusError(status: 0, code: "network_error", message: "No HTTP response")
    }

    guard (200..<300).contains(http.statusCode) else {
      // The API always sends a JSON error body, but a proxy or a captive
      // portal in between may not, so parsing it must never be what produces
      // the error the caller sees.
      let body = (try? decoder.decode(APIErrorBody.self, from: data)) ?? APIErrorBody()
      throw ArmenusError(
        status: http.statusCode,
        code: body.error ?? "http_error",
        message: body.message ?? "Request failed with status \(http.statusCode)",
        details: body.details?.rawJSON
      )
    }

    do {
      return try decoder.decode(T.self, from: data)
    } catch {
      throw ArmenusError(
        status: http.statusCode,
        code: "decode_error",
        message: "Could not decode the API response: \(error.localizedDescription)"
      )
    }
  }

  private func url(path: String, query: [URLQueryItem]) -> URL {
    var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
    let base = components.percentEncodedPath.hasSuffix("/")
      ? String(components.percentEncodedPath.dropLast())
      : components.percentEncodedPath
    components.percentEncodedPath = base + path
    components.queryItems = query.isEmpty ? nil : query
    return components.url!
  }

  /// `encodeURIComponent` semantics, so an id containing `/` or `?` cannot
  /// change the route it is sent to.
  private func encode(_ segment: String) -> String {
    segment.addingPercentEncoding(withAllowedCharacters: .armenusPathSegment) ?? segment
  }
}

private struct APIErrorBody: Decodable {
  var error: String?
  var message: String?
  var details: JSONValue?
}

/// Enough JSON to carry an arbitrary `details` payload back to the caller as
/// text without depending on a JSON library.
private enum JSONValue: Decodable {
  case string(String), number(Double), bool(Bool), null
  case array([JSONValue]), object([String: JSONValue])

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() { self = .null }
    else if let value = try? container.decode(Bool.self) { self = .bool(value) }
    else if let value = try? container.decode(Double.self) { self = .number(value) }
    else if let value = try? container.decode(String.self) { self = .string(value) }
    else if let value = try? container.decode([JSONValue].self) { self = .array(value) }
    else { self = .object(try container.decode([String: JSONValue].self)) }
  }

  var rawJSON: String {
    switch self {
    case .null: return "null"
    case .bool(let value): return value ? "true" : "false"
    case .number(let value):
      return value.rounded() == value ? String(Int(value)) : String(value)
    case .string(let value):
      let escaped = value
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
      return "\"\(escaped)\""
    case .array(let values):
      return "[" + values.map(\.rawJSON).joined(separator: ",") + "]"
    case .object(let values):
      return "{" + values.keys.sorted().map { "\"\($0)\":\(values[$0]!.rawJSON)" }.joined(separator: ",") + "}"
    }
  }
}

extension CharacterSet {
  /// Unreserved characters only: what `encodeURIComponent` leaves alone,
  /// minus the punctuation it also keeps, which is harmless to encode.
  static let armenusPathSegment = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_.~"))
}
