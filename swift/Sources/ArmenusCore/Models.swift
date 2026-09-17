import Foundation

/*
 The wire shape of the embed API.

 Hand-written to match `@armenus/sdk-core`'s `types.ts` field for field. The
 API is ours, so these are plain `Codable` structs with no tolerance layer: a
 field that appears on one platform and not another is a bug to fix in the
 API, not something to paper over here.
 */

/// USDZ readiness. Gates iOS entirely: see ``EmbedModel/usdzUrl``.
public enum UsdzStatus: String, Codable, Sendable {
  case pending
  case processing
  case ready
  case failed
}

/// Camera framing, passed through to whichever renderer the platform uses.
public struct ModelViewSettings: Codable, Equatable, Sendable {
  /// `"theta phi radius"`, e.g. `"0deg 75deg 105%"`. model-viewer's format,
  /// so one setting frames a dish identically on the web and natively.
  public var cameraOrbit: String
  /// `"x y z"`, or `"auto auto auto"`.
  public var cameraTarget: String
  /// `"auto"` or an angle such as `"30deg"`.
  public var fieldOfView: String
  public var exposure: Double
  public var shadowIntensity: Double
  public var autoRotate: Bool
  /// Multiplier applied before AR placement, on top of ``EmbedModel/physicalSizeM``.
  /// The size is a measurement; this is a correction a restaurant applies
  /// when the placed result still reads wrong. Native clients apply both.
  public var arScale: Double

  public init(
    cameraOrbit: String,
    cameraTarget: String,
    fieldOfView: String,
    exposure: Double,
    shadowIntensity: Double,
    autoRotate: Bool,
    arScale: Double
  ) {
    self.cameraOrbit = cameraOrbit
    self.cameraTarget = cameraTarget
    self.fieldOfView = fieldOfView
    self.exposure = exposure
    self.shadowIntensity = shadowIntensity
    self.autoRotate = autoRotate
    self.arScale = arScale
  }
}

public struct EmbedModel: Codable, Equatable, Sendable {
  public var id: String
  /// Android inline, Scene Viewer AR and every browser path.
  public var glbUrl: String
  /// iOS inline and Quick Look AR. `nil` until conversion finishes.
  ///
  /// On iOS this gates the inline preview as well as AR: SceneKit cannot load
  /// a GLB, so an iPhone with no USDZ has nothing to render and falls back to
  /// ``posterUrl``.
  public var usdzUrl: String?
  public var usdzStatus: UsdzStatus
  /// Shown while the mesh downloads, and wherever no mesh can be rendered.
  public var posterUrl: String?
  /// Longest side in metres. Required for AR placement at believable scale.
  public var physicalSizeM: Double
  /// Optimised GLB size. `nil` on rows predating the measurement.
  public var glbBytes: Int?
  public var viewSettings: ModelViewSettings

  public init(
    id: String,
    glbUrl: String,
    usdzUrl: String?,
    usdzStatus: UsdzStatus,
    posterUrl: String?,
    physicalSizeM: Double,
    glbBytes: Int?,
    viewSettings: ModelViewSettings
  ) {
    self.id = id
    self.glbUrl = glbUrl
    self.usdzUrl = usdzUrl
    self.usdzStatus = usdzStatus
    self.posterUrl = posterUrl
    self.physicalSizeM = physicalSizeM
    self.glbBytes = glbBytes
    self.viewSettings = viewSettings
  }
}

public struct EmbedMerchant: Codable, Equatable, Sendable {
  public var id: String
  public var slug: String
  public var name: String
  public var currency: String
  public var locale: String

  public init(id: String, slug: String, name: String, currency: String, locale: String) {
    self.id = id
    self.slug = slug
    self.name = name
    self.currency = currency
    self.locale = locale
  }
}

public struct EmbedItem: Codable, Equatable, Sendable {
  public var id: String
  public var slug: String
  /// The host app's own identifier, when it set one.
  public var externalRef: String?
  public var name: String
  public var description: String?
  public var priceCents: Int
  public var tags: [String]
  public var imageUrl: String?
  public var isAvailable: Bool
  public var merchant: EmbedMerchant
  /// `nil` when the dish has no model, or has one that is not ready yet.
  public var model: EmbedModel?

  public init(
    id: String,
    slug: String,
    externalRef: String?,
    name: String,
    description: String?,
    priceCents: Int,
    tags: [String],
    imageUrl: String?,
    isAvailable: Bool,
    merchant: EmbedMerchant,
    model: EmbedModel?
  ) {
    self.id = id
    self.slug = slug
    self.externalRef = externalRef
    self.name = name
    self.description = description
    self.priceCents = priceCents
    self.tags = tags
    self.imageUrl = imageUrl
    self.isAvailable = isAvailable
    self.merchant = merchant
    self.model = model
  }
}

public struct EmbedItemList: Codable, Equatable, Sendable {
  public var items: [EmbedItem]
  /// Opaque; changes whenever the list does. Cache keys derive from it.
  public var version: String

  public init(items: [EmbedItem], version: String) {
    self.items = items
    self.version = version
  }
}

public enum EmbedScope: String, Codable, Sendable {
  case partner
  case restaurant
}

/// What the key in hand is allowed to see. Fetch it once at startup so a
/// revoked or mistyped key fails loudly instead of presenting as an empty menu.
public struct EmbedConfig: Codable, Equatable, Sendable {
  public var scope: EmbedScope
  /// Display name of whoever owns the key.
  public var ownerName: String
  /// Every merchant this key can read. One entry for a restaurant-scoped key.
  public var merchants: [EmbedMerchant]

  public init(scope: EmbedScope, ownerName: String, merchants: [EmbedMerchant]) {
    self.scope = scope
    self.ownerName = ownerName
    self.merchants = merchants
  }
}
