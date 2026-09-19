#if os(iOS)
import XCTest
import SceneKit
import Network
import Armenus

final class NativeModelTests: XCTestCase {
  @MainActor
  func testNativeViewerLoadsUSDZAndClearsWhenReused() async throws {
    let fixture = Bundle.module.url(forResource: "triangle", withExtension: "usdz", subdirectory: "Fixtures")!
    let bytes = try Data(contentsOf: fixture)
    let listener = try NWListener(using: .tcp, on: .any)
    defer { listener.cancel() }
    let listening = expectation(description: "Local fixture server is ready")
    listener.stateUpdateHandler = { state in
      if case .ready = state { listening.fulfill() }
    }
    listener.newConnectionHandler = { connection in
      connection.start(queue: .global())
      connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { _, _, _, _ in
        var response = Data("HTTP/1.1 200 OK\r\nContent-Type: model/vnd.usdz+zip\r\nContent-Length: \(bytes.count)\r\nConnection: close\r\n\r\n".utf8)
        response.append(bytes)
        connection.send(content: response, completion: .contentProcessed { _ in connection.cancel() })
      }
    }
    listener.start(queue: .global())
    await fulfillment(of: [listening], timeout: 5)
    let port = try XCTUnwrap(listener.port).rawValue
    let json = """
    {"id":"dish","slug":"dish","name":"Test dish","priceCents":100,"tags":[],"isAvailable":true,
     "merchant":{"id":"restaurant","slug":"restaurant","name":"Restaurant","currency":"USD","locale":"en"},
     "model":{"id":"triangle","glbUrl":"https://sdk-fixture.invalid/triangle.glb",
       "usdzUrl":"http://127.0.0.1:\(port)/triangle.usdz","usdzStatus":"ready","physicalSizeM":0.2,
       "viewSettings":{"cameraOrbit":"0deg 75deg 105%","cameraTarget":"auto auto auto","fieldOfView":"auto","exposure":1,"shadowIntensity":1,"autoRotate":false,"arScale":1}}}
    """
    let dish = try JSONDecoder().decode(EmbedItem.self, from: Data(json.utf8))
    let view = ArmenusModelView(frame: CGRect(x: 0, y: 0, width: 300, height: 360))
    let loaded = expectation(description: "SceneKit imported the USDZ fixture")
    view.onModelLoad = { loaded.fulfill() }
    view.onModelError = { XCTFail($0); loaded.fulfill() }
    view.display(dish)
    await fulfillment(of: [loaded], timeout: 15)
    view.layoutIfNeeded()
    func sceneView(in view: UIView) -> SCNView? {
      if let scene = view as? SCNView { return scene }
      return view.subviews.compactMap { sceneView(in: $0) }.first
    }
    let scene = try XCTUnwrap(sceneView(in: view))
    XCTAssertNotNil(scene.scene)
    XCTAssertFalse(scene.isHidden)
    XCTAssertNotNil(scene.pointOfView)
    #if targetEnvironment(simulator)
    XCTAssertFalse(ArmenusAR.isSupported)
    #endif
    view.display(nil)
    XCTAssertNil(scene.scene)
    XCTAssertTrue(scene.isHidden)
  }
}
#endif
