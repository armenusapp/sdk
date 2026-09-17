import Flutter
import SceneKit
import UIKit

/**
 Platform-view factory for the inline preview.

 SceneKit, not RealityKit. RealityKit spins up an ARView with a render loop and
 a session per instance — heavy for a preview that is not doing AR, and it has
 no cheap "just draw this model on a plain background" path. SCNView is a plain
 UIView that draws a scene and stops when it is off screen.

 USDZ only: SceneKit has no glTF importer, which is why a missing USDZ blanks
 the preview on iOS and not just the AR button.
 */
class ArmenusModelViewFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(
    withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?
  ) -> FlutterPlatformView {
    ArmenusFlutterModelView(
      frame: frame,
      viewId: viewId,
      args: args as? [String: Any] ?? [:],
      messenger: messenger)
  }
}

class ArmenusFlutterModelView: NSObject, FlutterPlatformView {
  private let sceneView = SCNView()
  private let channel: FlutterMethodChannel
  private var modelNode: SCNNode?

  private let cameraOrbitTheta: Double
  private let cameraOrbitPhi: Double
  private let autoRotate: Bool

  init(
    frame: CGRect, viewId: Int64, args: [String: Any], messenger: FlutterBinaryMessenger
  ) {
    channel = FlutterMethodChannel(
      name: "app.armenus/model-view/\(viewId)", binaryMessenger: messenger)
    cameraOrbitTheta = args["cameraOrbitTheta"] as? Double ?? 0
    cameraOrbitPhi = args["cameraOrbitPhi"] as? Double ?? 75
    autoRotate = args["autoRotate"] as? Bool ?? true
    super.init()

    sceneView.frame = frame
    sceneView.backgroundColor = .clear
    sceneView.antialiasingMode = .multisampling4X
    // Physically-based lighting, so a dish authored for PBR is not flat.
    sceneView.autoenablesDefaultLighting = true
    sceneView.allowsCameraControl = args["interactionEnabled"] as? Bool ?? true

    /*
     Paused until a model loads. Each SCNView owns a CADisplayLink; a feed with
     twenty dish cards all rendering off screen drains the battery and drops
     the scroll below 60fps for nothing visible.
     */
    sceneView.rendersContinuously = false
    sceneView.isPlaying = false

    if let source = args["source"] as? String, !source.isEmpty {
      load(source)
    }
  }

  func view() -> UIView { sceneView }

  private func load(_ source: String) {
    let handle: (URL) -> Void = { [weak self] url in
      /*
       Parsed off the main thread. A textured dish is a few MB of USDZ and
       decoding it inline drops frames in whatever list the card sits in — the
       most visible performance mistake available here.
       */
      DispatchQueue.global(qos: .userInitiated).async {
        do {
          let scene = try SCNScene(url: url, options: [.checkConsistency: false])
          DispatchQueue.main.async { self?.install(scene: scene) }
        } catch {
          DispatchQueue.main.async {
            self?.channel.invokeMethod(
              "onModelError", arguments: ["message": error.localizedDescription])
          }
        }
      }
    }

    if source.hasPrefix("http") {
      // Routed through the same cache as the AR path, so a dish previewed and
      // then placed is downloaded once rather than twice.
      ArmenusModelCache.shared.file(for: source) { [weak self] local, error in
        if let local {
          handle(local)
        } else {
          DispatchQueue.main.async {
            self?.channel.invokeMethod(
              "onModelError",
              arguments: ["message": error?.localizedDescription ?? "Download failed"])
          }
        }
      }
    } else {
      handle(URL(fileURLWithPath: source))
    }
  }

  private func install(scene: SCNScene) {
    sceneView.scene = scene

    let node = SCNNode()
    for child in scene.rootNode.childNodes { node.addChildNode(child) }
    scene.rootNode.addChildNode(node)
    modelNode = node

    /*
     Re-centre on the bounding box. Exporters disagree about origin as wildly
     as they do about scale — a dish can arrive with its pivot metres from the
     mesh, and without this the camera frames empty space and the preview looks
     broken rather than mis-framed.
     */
    let (minBound, maxBound) = node.boundingBox
    node.pivot = SCNMatrix4MakeTranslation(
      (minBound.x + maxBound.x) / 2,
      (minBound.y + maxBound.y) / 2,
      (minBound.z + maxBound.z) / 2)

    applyCamera(node: node)

    if autoRotate {
      // One revolution every 18 seconds, matching web and Android.
      node.runAction(
        SCNAction.repeatForever(
          SCNAction.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 18)),
        forKey: "armenus-spin")
      sceneView.isPlaying = true
    }

    channel.invokeMethod("onModelLoad", arguments: nil)
  }

  private func applyCamera(node: SCNNode) {
    let (minBound, maxBound) = node.boundingBox
    let radius = max(
      maxBound.x - minBound.x,
      max(maxBound.y - minBound.y, maxBound.z - minBound.z)) / 2
    let distance = 1.05 * radius * 2.6

    // Spherical to Cartesian, matching model-viewer's convention so that one
    // `cameraOrbit` string frames the dish identically on every platform.
    let theta = Float(cameraOrbitTheta) * .pi / 180
    let phi = Float(cameraOrbitPhi) * .pi / 180

    let camera = SCNNode()
    camera.camera = SCNCamera()
    camera.position = SCNVector3(
      distance * sin(phi) * sin(theta),
      distance * cos(phi),
      distance * sin(phi) * cos(theta))
    camera.look(at: SCNVector3Zero)
    camera.camera?.zNear = Double(max(0.01, distance * 0.01))
    camera.camera?.zFar = Double(distance * 10)

    sceneView.scene?.rootNode.addChildNode(camera)
    sceneView.pointOfView = camera
  }
}
