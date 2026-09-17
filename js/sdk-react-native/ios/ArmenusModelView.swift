import Foundation
import SceneKit
import UIKit

/**
 Inline 3D preview on iOS.

 SceneKit, not RealityKit. RealityKit is the newer engine and the wrong tool
 for a card in a scrolling list: it spins up an ARView with a render loop and a
 session per instance, which is heavy for a preview that is not doing AR, and
 it has no cheap "just show me this model on a plain background" path. SCNView
 is a plain UIView that draws a scene and stops when it is off screen.

 USDZ only. SceneKit has no glTF importer, which is why `EmbedModel.usdzUrl`
 gates the preview on iOS and not only the AR button.
 */
@objc(ArmenusModelView)
public final class ArmenusModelView: UIView {

  private let sceneView = SCNView()
  private var modelNode: SCNNode?
  private var currentSource: String?

  @objc public var onModelLoad: (() -> Void)?
  @objc public var onModelError: ((String) -> Void)?

  /* -- props -------------------------------------------------------------- */

  @objc public var source: NSString = "" {
    didSet { loadIfNeeded() }
  }

  @objc public var cameraOrbitTheta: Double = 0 { didSet { applyCamera() } }
  @objc public var cameraOrbitPhi: Double = 75 { didSet { applyCamera() } }
  @objc public var cameraDistance: Double = 1.05 { didSet { applyCamera() } }

  @objc public var exposure: Double = 1 {
    didSet { sceneView.scene?.rootNode.light?.intensity = CGFloat(exposure * 1000) }
  }

  @objc public var shadowIntensity: Double = 1 { didSet { applyShadow() } }

  @objc public var autoRotate: Bool = true { didSet { applyAutoRotate() } }

  @objc public var interactionEnabled: Bool = true {
    didSet { sceneView.allowsCameraControl = interactionEnabled }
  }

  /* -- lifecycle ---------------------------------------------------------- */

  public override init(frame: CGRect) {
    super.init(frame: frame)
    setUp()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setUp()
  }

  private func setUp() {
    sceneView.frame = bounds
    sceneView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    sceneView.backgroundColor = .clear
    sceneView.antialiasingMode = .multisampling4X
    // Physically-based lighting, so a dish lit for PBR does not come out flat.
    sceneView.autoenablesDefaultLighting = true
    sceneView.allowsCameraControl = interactionEnabled

    /*
     Paused until a model is loaded, and paused again when the view leaves the
     window. Each SCNView owns a CADisplayLink; a feed with twenty dish cards
     that all keep rendering off screen will drain a battery and drop the
     scroll below 60fps for no visible benefit.
     */
    sceneView.rendersContinuously = false
    sceneView.isPlaying = false

    addSubview(sceneView)
  }

  public override func didMoveToWindow() {
    super.didMoveToWindow()
    sceneView.isPlaying = window != nil && autoRotate && modelNode != nil
  }

  /* -- loading ------------------------------------------------------------ */

  private func loadIfNeeded() {
    let path = source as String
    guard !path.isEmpty, path != currentSource else { return }
    currentSource = path

    // A local path from `prefetch` loads synchronously off disk; a remote URL
    // is routed through the same cache so the two paths cannot diverge.
    if path.hasPrefix("http") {
      ArmenusModelCache.shared.file(for: path) { [weak self] local, error in
        guard let self else { return }
        DispatchQueue.main.async {
          if let local {
            self.loadScene(from: local)
          } else {
            self.onModelError?(error?.localizedDescription ?? "Download failed")
          }
        }
      }
    } else {
      loadScene(from: URL(fileURLWithPath: path))
    }
  }

  private func loadScene(from url: URL) {
    /*
     Parsed off the main thread. A textured dish is a few MB of USDZ and
     decoding it inline drops frames in whatever list the card is sitting in —
     the single most visible performance mistake available here.
     */
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      do {
        let scene = try SCNScene(url: url, options: [.checkConsistency: false])
        DispatchQueue.main.async {
          guard let self else { return }
          self.install(scene: scene)
        }
      } catch {
        DispatchQueue.main.async {
          self?.onModelError?(error.localizedDescription)
        }
      }
    }
  }

  private func install(scene: SCNScene) {
    sceneView.scene = scene

    let node = SCNNode()
    for child in scene.rootNode.childNodes {
      node.addChildNode(child)
    }
    scene.rootNode.addChildNode(node)
    modelNode = node

    /*
     Re-centre on the bounding box.

     Exporters disagree about origin as wildly as they do about scale — a dish
     can arrive with its pivot metres away from the mesh. Without this the
     camera frames empty space and the preview looks broken rather than
     mis-framed.
     */
    let (minBound, maxBound) = node.boundingBox
    let centre = SCNVector3(
      (minBound.x + maxBound.x) / 2,
      (minBound.y + maxBound.y) / 2,
      (minBound.z + maxBound.z) / 2)
    node.pivot = SCNMatrix4MakeTranslation(centre.x, centre.y, centre.z)

    applyCamera()
    applyShadow()
    applyAutoRotate()

    sceneView.isPlaying = window != nil && autoRotate
    onModelLoad?()
  }

  /* -- framing ------------------------------------------------------------ */

  private func applyCamera() {
    guard let node = modelNode else { return }

    let (minBound, maxBound) = node.boundingBox
    let extent = SCNVector3(
      maxBound.x - minBound.x, maxBound.y - minBound.y, maxBound.z - minBound.z)
    let radius = max(extent.x, max(extent.y, extent.z)) / 2
    let distance = Float(cameraDistance) * radius * 2.6

    // Spherical to Cartesian, matching model-viewer's convention so that one
    // `cameraOrbit` string frames the dish identically on web and native.
    let theta = Float(cameraOrbitTheta) * .pi / 180
    let phi = Float(cameraOrbitPhi) * .pi / 180

    let camera = sceneView.pointOfView ?? {
      let node = SCNNode()
      node.camera = SCNCamera()
      sceneView.scene?.rootNode.addChildNode(node)
      sceneView.pointOfView = node
      return node
    }()

    camera.position = SCNVector3(
      distance * sin(phi) * sin(theta),
      distance * cos(phi),
      distance * sin(phi) * cos(theta))
    camera.look(at: SCNVector3Zero)
    camera.camera?.zNear = Double(max(0.01, distance * 0.01))
    camera.camera?.zFar = Double(distance * 10)
  }

  private func applyShadow() {
    guard let scene = sceneView.scene else { return }

    let existing = scene.rootNode.childNode(withName: "armenus-key", recursively: false)
    let node = existing ?? SCNNode()
    node.name = "armenus-key"

    let light = node.light ?? SCNLight()
    light.type = .directional
    light.castsShadow = shadowIntensity > 0
    light.shadowMode = .deferred
    light.shadowRadius = 8
    light.shadowColor = UIColor.black.withAlphaComponent(CGFloat(0.4 * shadowIntensity))
    node.light = light
    node.eulerAngles = SCNVector3(-Float.pi / 3, Float.pi / 5, 0)

    if existing == nil { scene.rootNode.addChildNode(node) }
  }

  private func applyAutoRotate() {
    guard let node = modelNode else { return }
    node.removeAction(forKey: "armenus-spin")

    guard autoRotate else {
      sceneView.isPlaying = false
      return
    }

    let spin = SCNAction.repeatForever(
      SCNAction.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 18))
    node.runAction(spin, forKey: "armenus-spin")
    sceneView.isPlaying = window != nil
  }
}
