import XCTest
@testable import ArmenusCore

/// Intercepts every request the client makes so the transport can be tested
/// without a network: what it sends, and how it reacts to what comes back.
final class StubURLProtocol: URLProtocol {
  nonisolated(unsafe) static var handler: ((URLRequest) -> (Int, Data))?
  nonisolated(unsafe) static var requests: [URLRequest] = []

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    Self.requests.append(request)
    guard let handler = Self.handler else {
      client?.urlProtocol(self, didFailWithError: URLError(.cannotConnectToHost))
      return
    }
    let (status, body) = handler(request)
    let response = HTTPURLResponse(
      url: request.url!, statusCode: status, httpVersion: "HTTP/1.1",
      headerFields: ["Content-Type": "application/json"])!
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: body)
    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() {}
}

final class ClientTests: XCTestCase {
  private var session: URLSession!

  override func setUp() {
    super.setUp()
    StubURLProtocol.requests = []
    StubURLProtocol.handler = nil
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [StubURLProtocol.self]
    session = URLSession(configuration: configuration)
  }

  private func client(retries: Int = 2) throws -> ArmenusClient {
    try ArmenusClient(
      publishableKey: "pk_abc123_secretpart",
      baseURL: URL(string: "https://api.test/v1")!,
      timeout: 2,
      retries: retries,
      session: session)
  }

  static let itemJSON = Data("""
    {
      "id": "item-1", "slug": "burger", "externalRef": "SKU-1234", "name": "Burger",
      "description": null, "priceCents": 847, "tags": ["beef"], "imageUrl": null,
      "isAvailable": true,
      "merchant": {"id": "m-1", "slug": "zburger", "name": "Z Burger", "currency": "USD", "locale": "en-US"},
      "model": {
        "id": "model-1", "glbUrl": "https://cdn.test/a.glb", "usdzUrl": null,
        "usdzStatus": "processing", "posterUrl": "https://cdn.test/a.webp",
        "physicalSizeM": 0.22, "glbBytes": null,
        "viewSettings": {"cameraOrbit": "0deg 75deg 105%", "cameraTarget": "auto auto auto",
          "fieldOfView": "auto", "exposure": 1, "shadowIntensity": 1, "autoRotate": true, "arScale": 1}
      }
    }
    """.utf8)

  func testRejectsSecretAndMalformedKeys() {
    XCTAssertThrowsError(try ArmenusClient(publishableKey: "ak_secret_key")) { error in
      XCTAssertEqual((error as? ArmenusError)?.code, "invalid_key")
      XCTAssertTrue(((error as? ArmenusError)?.message ?? "").contains("secret"))
    }
    XCTAssertThrowsError(try ArmenusClient(publishableKey: ""))
    XCTAssertNoThrow(try ArmenusClient(publishableKey: "pk_ok"))
  }

  func testSendsBearerKeyAndEncodesPathSegments() async throws {
    StubURLProtocol.handler = { _ in (200, ClientTests.itemJSON) }

    let item = try await client().item(merchantID: "m/1", externalRef: "SKU 12?4")
    XCTAssertEqual(item.externalRef, "SKU-1234")
    XCTAssertNil(item.model?.usdzUrl)
    XCTAssertEqual(item.model?.usdzStatus, .processing)
    XCTAssertNil(item.description)

    let request = try XCTUnwrap(StubURLProtocol.requests.first)
    XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer pk_abc123_secretpart")
    XCTAssertEqual(
      request.url?.absoluteString,
      "https://api.test/v1/embed/merchants/m%2F1/items/by-ref/SKU%2012%3F4")
  }

  func testListQueryParameters() async throws {
    StubURLProtocol.handler = { _ in (200, Data(#"{"items":[],"version":"v9"}"#.utf8)) }

    let list = try await client().items(merchantID: "m-1", withModel: true, limit: 20, offset: 40)
    XCTAssertEqual(list.version, "v9")
    XCTAssertEqual(
      StubURLProtocol.requests.first?.url?.absoluteString,
      "https://api.test/v1/embed/merchants/m-1/items?withModel=true&limit=20&offset=40")
  }

  func testEmptyIdListIsNotSent() async throws {
    let list = try await client().items(ids: [])
    XCTAssertTrue(list.items.isEmpty)
    XCTAssertTrue(StubURLProtocol.requests.isEmpty)
  }

  func testAuthErrorsAreNotRetried() async throws {
    StubURLProtocol.handler = { _ in
      (401, Data(#"{"error":"unauthorized","message":"A publishable key is required."}"#.utf8))
    }

    do {
      _ = try await client().config()
      XCTFail("expected an error")
    } catch let error as ArmenusError {
      XCTAssertEqual(error.status, 401)
      XCTAssertEqual(error.code, "unauthorized")
      XCTAssertTrue(error.isAuthError)
      XCTAssertFalse(error.isRetryable)
    }
    XCTAssertEqual(StubURLProtocol.requests.count, 1)
  }

  func testServerFaultsAreRetriedThenSucceed() async throws {
    var calls = 0
    StubURLProtocol.handler = { _ in
      calls += 1
      return calls == 1
        ? (503, Data(#"{"error":"unavailable","message":"try again"}"#.utf8))
        : (200, Data(#"{"scope":"restaurant","ownerName":"Z","merchants":[]}"#.utf8))
    }

    let config = try await client(retries: 3).config()
    XCTAssertEqual(config.scope, .restaurant)
    XCTAssertEqual(StubURLProtocol.requests.count, 2)
  }

  func testNonJsonErrorBodyStillProducesAnError() async throws {
    StubURLProtocol.handler = { _ in (502, Data("<html>bad gateway</html>".utf8)) }

    do {
      _ = try await client(retries: 1).config()
      XCTFail("expected an error")
    } catch let error as ArmenusError {
      XCTAssertEqual(error.status, 502)
      XCTAssertEqual(error.code, "http_error")
      XCTAssertTrue(error.isRetryable)
    }
  }

  func testErrorDetailsAreCarriedAsJson() async throws {
    StubURLProtocol.handler = { _ in
      (400, Data(#"{"error":"bad_request","message":"nope","details":[{"path":"ids","message":"too many"}]}"#.utf8))
    }

    do {
      _ = try await client(retries: 1).items(ids: ["a"])
      XCTFail("expected an error")
    } catch let error as ArmenusError {
      XCTAssertEqual(error.details, #"[{"message":"too many","path":"ids"}]"#)
    }
  }
}
