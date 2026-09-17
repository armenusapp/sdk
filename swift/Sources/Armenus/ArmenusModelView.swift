#if os(iOS)
import SceneKit
import UIKit

/// A dish in 3D, with AR where the handset supports it. UIKit.
///
/// SceneKit, not RealityKit. RealityKit spins up an ARView with a render loop
/// and a session per instance, which is heavy for a card in a scrolling list
/// that is not doing AR. `SCNView` is a plain view that draws a scene and stops
/// when it is off screen.
///
/// USDZ only. SceneKit has no glTF importer, which is why `EmbedModel.usdzUrl`
/// gates the preview on iOS and not only the AR button. The view never
/// second-guesses ``resolvePresentation(platform:model:arCoreAvailable:hasWebXR:isMobileWeb:)``:
/// what it draws is whatever that returned.
public final class ArmenusModelView: UIView {

  // MARK: Configuration

  public var arLabel: String = "View on your table" {
    didSet { applyButtonStyle() }
  }

  /// Whether a drag rotates the model. Pass false inside a scrolling list: on
  /// a phone the two gesture systems fight, and a card that swallows vertical
  /// drags makes the whole feed feel stuck.
  public var interactionEnabled: Bool = true {
    didSet { sceneView.allowsCameraControl = interactionEnabled }
  }

  /// Background of the AR button.
  public var accentColor: UIColor = UIColor(red: 0.137, green: 0.302, blue: 0.235, alpha: 1) {
    didSet { applyButtonStyle() }
  }

  public var onModelLoad: (() -> Void)?
  public var onModelError: ((String) -> Void)?
  public var onEnterAR: ((EmbedItem) -> Void)?

  public private(set) var item: EmbedItem?
  public private(set) var presentation = resolvePresentation(platform: .iOS, model: nil)

  // MARK: Subviews

  private let stage = UIView()
  private let sceneView = SCNView()
  private let posterView = UIImageView()
  private let spinner = UIActivityIndicatorView(style: .medium)
  private let arButton = UIButton(type: .system)
  private let noteLabel = UILabel()

  private var modelNode: SCNNode?
  private var currentSource: String?
  private var posterTask: Task<Void, Never>?
  private var presenting = false

  // MARK: Lifecycle

  public override init(frame: CGRect) {
    super.init(frame: frame)
    setUp()
  }

  public required init?(coder: NSCoder) {
    super.init(coder: coder)
    setUp()
  }

  private func setUp() {
    stage.backgroundColor = UIColor(red: 0.957, green: 0.949, blue: 0.953, alpha: 1)
    stage.layer.cornerRadius = 14
    stage.clipsToBounds = true

    posterView.contentMode = .scaleAspectFit

    sceneView.backgroundColor = .clear
    sceneView.antialiasingMode = .multisampling4X
    // Physically based lighting, so a dish lit for PBR does not come out flat.
    sceneView.autoenablesDefaultLighting = true
    sceneView.allowsCameraControl = interactionEnabled
    // Paused until a model is loaded, and paused when the view leaves the
    // window. Each SCNView owns a CADisplayLink; twenty dish cards rendering
    // off screen drain a battery and drop the scroll below 60fps for nothing.
    sceneView.rendersContinuously = false
    sceneView.isPlaying = false
    sceneView.isHidden = true

    spinner.hidesWhenStopped = true

    applyButtonStyle()
    arButton.isHidden = true
    arButton.addTarget(self, action: #selector(enterAR), for: .touchUpInside)

    noteLabel.font = .systemFont(ofSize: 13)
    noteLabel.textColor = .secondaryLabel
    noteLabel.textAlignment = .center
    noteLabel.numberOfLines = 0
    noteLabel.isHidden = true

    for view in [stage, noteLabel] {
      view.translatesAutoresizingMaskIntoConstraints = false
      addSubview(view)
    }
    for view in [posterView, sceneView, spinner, arButton] {
      view.translatesAutoresizingMaskIntoConstraints = false
      stage.addSubview(view)
    }

    NSLayoutConstraint.activate([
      stage.topAnchor.constraint(equalTo: topAnchor),
      stage.leadingAnchor.constraint(equalTo: leadingAnchor),
      stage.trailingAnchor.constraint(equalTo: trailingAnchor),
      stage.heightAnchor.constraint(equalTo: stage.widthAnchor),

      noteLabel.topAnchor.constraint(equalTo: stage.bottomAnchor, constant: 10),
      noteLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
      noteLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
      noteLabel.bottomAnchor.constraint(equalTo: bottomAnchor),

      posterView.topAnchor.constraint(equalTo: stage.topAnchor),
      posterView.leadingAnchor.constraint(equalTo: stage.leadingAnchor),
      posterView.trailingAnchor.constraint(equalTo: stage.trailingAnchor),
      posterView.bottomAnchor.constraint(equalTo: stage.bottomAnchor),

      sceneView.topAnchor.constraint(equalTo: stage.topAnchor),
      sceneView.leadingAnchor.constraint(equalTo: stage.leadingAnchor),
      sceneView.trailingAnchor.constraint(equalTo: stage.trailingAnchor),
      sceneView.bottomAnchor.constraint(equalTo: stage.bottomAnchor),

      spinner.centerXAnchor.constraint(equalTo: stage.centerXAnchor),
      spinner.centerYAnchor.constraint(equalTo: stage.centerYAnchor),

      // 44pt minimum touch target.
      arButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
      arButton.centerXAnchor.constraint(equalTo: stage.centerXAnchor),
      arButton.bottomAnchor.constraint(equalTo: stage.bottomAnchor, constant: -16),
    ])
  }

  private func applyButtonStyle() {
    var configuration = UIButton.Configuration.filled()
    configuration.baseBackgroundColor = accentColor
    configuration.baseForegroundColor = .white
    configuration.cornerStyle = .capsule
    configuration.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
    configuration.attributedTitle = AttributedString(
      arLabel, attributes: AttributeContainer([.font: UIFont.systemFont(ofSize: 15, weight: .semibold)]))
    arButton.configuration = configuration
    arButton.accessibilityLabel = arLabel
  }

  public override func didMoveToWindow() {
    super.didMoveToWindow()
    sceneView.isPlaying = window != nil && modelNode != nil && (item?.model?.viewSettings.autoRotate ?? false)
  }

  // MARK: Display

  /// Shows a dish. Pass `nil` to clear the view.
  public func display(_ item: EmbedItem?) {
    self.item = item
    presentation = resolvePresentation(platform: .iOS, model: item?.model)

    // The poster stays mounted beneath the canvas until the mesh reports in,
    // so there is never a blank frame between the two.
    let posterURL: String?
    if case .poster(let url) = presentation.inline {
      posterURL = url
    } else {
      posterURL = item?.model?.posterUrl ?? item?.imageUrl
    }
    loadPoster(posterURL)

    if case .usdz(let url) = presentation.inline, let settings = item?.model?.viewSettings {
      loadMesh(url, settings: settings)
    } else {
      clearMesh()
    }

    let offersAR = presentation.ar.supported && ArmenusAR.isSupported
    arButton.isHidden = !offersAR
    noteLabel.text = presentation.ar.reason
    noteLabel.isHidden = presentation.ar.reason == nil

    if offersAR, let usdz = item?.model?.usdzUrl {
      // Warm the cache as soon as AR is offerable rather than on tap. Quick
      // Look needs a local file either way; only the timing is ours.
      Task { _ = try? await ArmenusModelCache.shared.file(for: usdz) }
    }
  }

  private func loadPoster(_ urlString: String?) {
    posterTask?.cancel()
    posterView.image = nil
    guard let urlString, let url = URL(string: urlString) else { return }
    posterTask = Task { [weak self] in
      guard let (data, _) = try? await URLSession.shared.data(from: url), !Task.isCancelled else { return }
      let image = UIImage(data: data)
      await MainActor.run { self?.posterView.image = image }
    }
  }

  // MARK: Mesh

  private func loadMesh(_ source: String, settings: ModelViewSettings) {
    guard source != currentSource else { return }
    currentSource = source
    clearScene()
    spinner.startAnimating()

    ArmenusModelCache.shared.file(for: source) { [weak self] local, error in
      DispatchQueue.main.async {
        guard let self, self.currentSource == source else { return }
        guard let local else {
          self.spinner.stopAnimating()
          self.onModelError?(error?.localizedDescription ?? "Download failed")
          return
        }
        self.loadScene(from: local, settings: settings)
      }
    }
  }

  private func clearMesh() {
    currentSource = nil
    clearScene()
    spinner.stopAnimating()
  }

  private func clearScene() {
    modelNode?.removeAllActions()
    modelNode = nil
    sceneView.scene = nil
    sceneView.isPlaying = false
    sceneView.isHidden = true
  }

  private func loadScene(from url: URL, settings: ModelViewSettings) {
    // Parsed off the main thread. A textured dish is a few MB of USDZ and
    // decoding it inline drops frames in whatever list the card sits in.
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      do {
        let scene = try SCNScene(url: url, options: [.checkConsistency: false])
        DispatchQueue.main.async {
          guard let self, self.currentSource != nil else { return }
          self.install(scene: scene, settings: settings)
        }
      } catch {
        DispatchQueue.main.async {
          self?.spinner.stopAnimating()
          self?.onModelError?(error.localizedDescription)
        }
      }
    }
  }

  private func install(scene: SCNScene, settings: ModelViewSettings) {
    sceneView.scene = scene

    let node = SCNNode()
    for child in scene.rootNode.childNodes {
      node.addChildNode(child)
    }
    scene.rootNode.addChildNode(node)
    modelNode = node

    // Re-centre on the bounding box. Exporters disagree about origin as wildly
    // as they do about scale; without this the camera can frame empty space.
    let (minBound, maxBound) = node.boundingBox
    let centre = SCNVector3(
      (minBound.x + maxBound.x) / 2,
      (minBound.y + maxBound.y) / 2,
      (minBound.z + maxBound.z) / 2)
    node.pivot = SCNMatrix4MakeTranslation(centre.x, centre.y, centre.z)

    applyCamera(CameraOrbit(parsing: settings.cameraOrbit))
    applyLight(exposure: settings.exposure, shadowIntensity: settings.shadowIntensity)
    applyAutoRotate(settings.autoRotate)

    sceneView.isHidden = false
    spinner.stopAnimating()
    onModelLoad?()
  }

  private func applyCamera(_ orbit: CameraOrbit) {
    guard let node = modelNode else { return }

    let (minBound, maxBound) = node.boundingBox
    let extent = SCNVector3(
      maxBound.x - minBound.x, maxBound.y - minBound.y, maxBound.z - minBound.z)
    let radius = max(extent.x, max(extent.y, extent.z)) / 2
    let distance = Float(orbit.radius) * radius * 2.6

    // Spherical to Cartesian, matching model-viewer's convention so that one
    // `cameraOrbit` string frames the dish identically on web and native.
    let theta = Float(orbit.theta) * .pi / 180
    let phi = Float(orbit.phi) * .pi / 180

    let camera = sceneView.pointOfView ?? {
      let cameraNode = SCNNode()
      cameraNode.camera = SCNCamera()
      sceneView.scene?.rootNode.addChildNode(cameraNode)
      sceneView.pointOfView = cameraNode
      return cameraNode
    }()

    camera.position = SCNVector3(
      distance * sin(phi) * sin(theta),
      distance * cos(phi),
      distance * sin(phi) * cos(theta))
    camera.look(at: SCNVector3Zero)
    camera.camera?.zNear = Double(max(0.01, distance * 0.01))
    camera.camera?.zFar = Double(distance * 10)
  }

  private func applyLight(exposure: Double, shadowIntensity: Double) {
    guard let scene = sceneView.scene else { return }

    let node = SCNNode()
    node.name = "armenus-key"
    let light = SCNLight()
    light.type = .directional
    light.intensity = CGFloat(exposure * 1000)
    light.castsShadow = shadowIntensity > 0
    light.shadowMode = .deferred
    light.shadowRadius = 8
    light.shadowColor = UIColor.black.withAlphaComponent(CGFloat(0.4 * shadowIntensity))
    node.light = light
    node.eulerAngles = SCNVector3(-Float.pi / 3, Float.pi / 5, 0)
    scene.rootNode.addChildNode(node)
  }

  private func applyAutoRotate(_ enabled: Bool) {
    guard let node = modelNode else { return }
    node.removeAction(forKey: "armenus-spin")

    guard enabled else {
      sceneView.isPlaying = false
      return
    }

    // One revolution every 18 seconds, matching the web and Android viewers.
    let spin = SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 18))
    node.runAction(spin, forKey: "armenus-spin")
    sceneView.isPlaying = window != nil
  }

  // MARK: AR

  @objc private func enterAR() {
    guard let item, let usdz = item.model?.usdzUrl, !presenting else { return }
    presenting = true
    onEnterAR?(item)

    Task { @MainActor [weak self] in
      do {
        // Life-size and fixed: the model is already scaled to the dish's real
        // dimensions, which is the whole question being asked.
        try await ArmenusAR.present(usdzURL: usdz, allowScaling: false)
      } catch {
        self?.onModelError?(error.localizedDescription)
      }
      self?.presenting = false
    }
  }
}
#endif
