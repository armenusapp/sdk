import Foundation

/*
 What a given device can actually do with a given model.

 A direct port of `resolvePresentation()` from `@armenus/sdk-core`, and kept
 as a pure function for the same reason: the rules are non-obvious in ways
 that produce dead buttons and blank canvases when guessed at.

   • There is no cross-platform AR API. WebXR, Scene Viewer and AR Quick Look
     are mutually exclusive; a device supports at most one.
   • There is no cross-platform model format. Quick Look and SceneKit read
     USDZ and cannot read GLB; Scene Viewer and Filament read GLB and cannot
     read USDZ.
   • On iOS a missing USDZ therefore costs the inline preview too, not just
     AR. There is nothing an iPhone can render.
 */

public enum Platform: Sendable {
  case iOS
  case android
  case webOther
}

public enum ARMode: String, Sendable {
  /// In-page immersive session. Chrome and Edge on Android.
  case webXR = "webxr"
  /// Android's system AR app, launched by intent. GLB.
  case sceneViewer = "scene-viewer"
  /// iOS and iPadOS system AR. USDZ only.
  case quickLook = "quick-look"
  case none
}

/// Which asset the inline (non-AR) preview should load, if any.
public enum InlineSource: Equatable, Sendable {
  case glb(url: String)
  case usdz(url: String)
  /// No renderable mesh for this platform; show the still image.
  case poster(url: String)
  /// Nothing at all to show. The caller renders its own empty state.
  case none

  /// The URL to load, when there is one.
  public var url: String? {
    switch self {
    case .glb(let url), .usdz(let url), .poster(let url): return url
    case .none: return nil
    }
  }
}

public struct ARAvailability: Equatable, Sendable {
  public let mode: ARMode
  /// True when the user can actually place this model in their room.
  public let supported: Bool
  /// Why not, written to be shown to a user. `nil` when supported.
  public let reason: String?
  /// True when the only thing missing is the USDZ conversion, a state that
  /// resolves by itself in a minute or two. Separated from every other
  /// unsupported case because it is the one where "check back shortly" is
  /// honest rather than a permanent-looking failure.
  public let blockedOnConversion: Bool

  public init(mode: ARMode, supported: Bool, reason: String?, blockedOnConversion: Bool) {
    self.mode = mode
    self.supported = supported
    self.reason = reason
    self.blockedOnConversion = blockedOnConversion
  }

  static func unsupported(_ reason: String) -> ARAvailability {
    ARAvailability(mode: .none, supported: false, reason: reason, blockedOnConversion: false)
  }

  static func supported(_ mode: ARMode) -> ARAvailability {
    ARAvailability(mode: mode, supported: true, reason: nil, blockedOnConversion: false)
  }
}

public struct Presentation: Equatable, Sendable {
  public let inline: InlineSource
  public let ar: ARAvailability

  public init(inline: InlineSource, ar: ARAvailability) {
    self.inline = inline
    self.ar = ar
  }
}

/// Resolves what to render and whether AR is offerable.
///
/// - Parameters:
///   - platform: Apps pass `.iOS`. The other cases exist so the rules stay
///     identical to the web and Android SDKs and can be tested side by side.
///   - arCoreAvailable: Android only. Whether ARCore is installed and supported.
///   - hasWebXR: Web only.
///   - isMobileWeb: Web only; tells a phone from a desktop with no headset.
public func resolvePresentation(
  platform: Platform,
  model: EmbedModel?,
  arCoreAvailable: Bool = false,
  hasWebXR: Bool = false,
  isMobileWeb: Bool = false
) -> Presentation {
  guard let model else {
    return Presentation(
      inline: .none,
      ar: .unsupported("This dish does not have a 3D model yet.")
    )
  }

  let poster: InlineSource = model.posterUrl.map { .poster(url: $0) } ?? .none

  switch platform {
  case .iOS:
    guard let usdz = model.usdzUrl else {
      // The wide gate. SceneKit cannot open a GLB, so with no USDZ an iPhone
      // has no mesh to draw at all: the preview itself falls back to a
      // photograph, not only the AR button.
      if model.usdzStatus == .failed {
        return Presentation(
          inline: poster,
          ar: .unsupported("The AR version of this dish is unavailable.")
        )
      }
      return Presentation(
        inline: poster,
        ar: ARAvailability(
          mode: .none,
          supported: false,
          reason: "The AR version of this dish is still being prepared.",
          blockedOnConversion: true
        )
      )
    }
    return Presentation(inline: .usdz(url: usdz), ar: .supported(.quickLook))

  case .android:
    // Filament renders the GLB regardless of ARCore: a handset with no AR
    // support still gets a model it can spin, which is most of the value.
    return Presentation(
      inline: .glb(url: model.glbUrl),
      ar: arCoreAvailable
        ? .supported(.sceneViewer)
        : .unsupported("This device does not support AR. You can still view the dish in 3D.")
    )

  case .webOther:
    let inline: InlineSource = .glb(url: model.glbUrl)
    if hasWebXR {
      return Presentation(inline: inline, ar: .supported(.webXR))
    }
    if !isMobileWeb {
      return Presentation(
        inline: inline,
        ar: .unsupported("Scan the QR code with your phone to view this dish in AR.")
      )
    }
    return Presentation(
      inline: inline,
      ar: .unsupported(
        "This browser does not support AR. Open the page in Chrome or Safari to place the dish on your table."
      )
    )
  }
}

/// Parsed camera framing from a model-viewer `camera-orbit` string.
///
/// The wire format is model-viewer's (`"0deg 75deg 105%"`) because the same
/// framing drives the web SDK verbatim. Native renderers take numbers, so it
/// is parsed here rather than stored twice and allowed to disagree.
public struct CameraOrbit: Equatable, Sendable {
  /// Azimuth in degrees.
  public var theta: Double
  /// Polar angle in degrees; 90 is level with the dish.
  public var phi: Double
  /// Distance multiplier; 1.0 frames the model, 1.05 leaves a small margin.
  public var radius: Double

  public init(theta: Double = 0, phi: Double = 75, radius: Double = 1.05) {
    self.theta = theta
    self.phi = phi
    self.radius = radius
  }

  public init(parsing orbit: String) {
    let parts = orbit.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
    self.init(
      theta: CameraOrbit.degrees(parts.count > 0 ? parts[0] : nil, fallback: 0),
      phi: CameraOrbit.degrees(parts.count > 1 ? parts[1] : nil, fallback: 75),
      radius: CameraOrbit.radius(parts.count > 2 ? parts[2] : nil, fallback: 1.05)
    )
  }

  private static func number(_ part: String) -> Double? {
    let digits = part.prefix { $0.isNumber || $0 == "." || $0 == "-" || $0 == "+" }
    return Double(digits)
  }

  private static func degrees(_ part: String?, fallback: Double) -> Double {
    guard let part, let value = number(part) else { return fallback }
    // Radians are legal in the format too, and are not the unit we return.
    return part.hasSuffix("rad") ? value * 180 / .pi : value
  }

  private static func radius(_ part: String?, fallback: Double) -> Double {
    guard let part, let value = number(part) else { return fallback }
    // "105%" means 1.05 times the framing distance; "auto" keeps the default.
    return part.hasSuffix("%") ? value / 100 : value
  }
}
