#if os(iOS)
import ARKit
import QuickLook
import UIKit

/// AR placement, via the system viewer.
///
/// There is no ARKit session code here and there should not be.
/// `QLPreviewController` in AR mode *is* ARKit: plane detection, real-world
/// scale, people occlusion, contact shadows and the drag, rotate and scale
/// gestures every iPhone user already knows from Safari and Messages.
///
/// The one thing Quick Look will not do is fetch a remote file, which is why
/// the cache exists and why ``prefetch(_:)`` is worth calling before the button
/// is tapped.
public enum ArmenusAR {
  /// Whether this handset can do AR at all.
  ///
  /// `ARWorldTrackingConfiguration.isSupported` is the real test. Checking the
  /// iOS version instead is the common mistake: it says nothing about the
  /// chip, and it is false in the simulator, where the check is also false.
  public static var isSupported: Bool {
    ARWorldTrackingConfiguration.isSupported
  }

  /// Warms the cache so the AR button opens instantly instead of stalling for
  /// two seconds while the user wonders whether the tap registered.
  @discardableResult
  public static func prefetch(_ usdzURL: String) async throws -> URL {
    try await ArmenusModelCache.shared.file(for: usdzURL)
  }

  /// Presents the dish in AR Quick Look and returns once the viewer is
  /// dismissed.
  ///
  /// - Parameters:
  ///   - usdzURL: `EmbedModel.usdzUrl`. A GLB cannot be shown here.
  ///   - allowScaling: Whether the user may pinch-scale the model. Defaults
  ///     to false, and that default is the point: the model is already scaled
  ///     to the dish's real dimensions, which is the question a diner is
  ///     asking. Letting them resize it turns an answer back into a guess.
  ///   - presenter: The view controller to present from. Defaults to the
  ///     topmost presented controller of the active scene.
  @MainActor
  public static func present(
    usdzURL: String,
    allowScaling: Bool = false,
    from presenter: UIViewController? = nil
  ) async throws {
    let local = try await ArmenusModelCache.shared.file(for: usdzURL)

    guard let host = presenter ?? topViewController() else {
      throw ArmenusARError.noPresenter
    }

    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      let controller = QLPreviewController()
      let source = ArmenusPreviewSource(fileURL: local, allowScaling: allowScaling)
      controller.dataSource = source
      controller.delegate = source

      // The data source is held weakly by QLPreviewController, so without
      // this it deallocates immediately and the preview opens blank.
      retainedSource = source
      source.onDismiss = {
        retainedSource = nil
        continuation.resume()
      }

      host.present(controller, animated: true)
    }
  }

  @MainActor private static var retainedSource: ArmenusPreviewSource?

  /// Walks presented controllers rather than using the root directly: in a
  /// real app the dish card is usually already inside a presented modal, and
  /// presenting from the root there throws "already presenting".
  @MainActor
  static func topViewController() -> UIViewController? {
    let scene = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first { $0.activationState == .foregroundActive }

    var top = scene?.windows.first(where: \.isKeyWindow)?.rootViewController
    while let presented = top?.presentedViewController {
      top = presented
    }
    return top
  }
}

public enum ArmenusARError: LocalizedError {
  case noPresenter

  public var errorDescription: String? {
    switch self {
    case .noPresenter: return "No view controller to present AR from"
    }
  }
}

/// Bridges the file to Quick Look and carries the AR-specific options.
///
/// `ARQuickLookPreviewItem` rather than the plain file URL: it is the only way
/// to set `allowsContentScaling`, and turning that off is what keeps the dish
/// at the size it actually is.
final class ArmenusPreviewSource: NSObject, QLPreviewControllerDataSource, QLPreviewControllerDelegate {
  private let fileURL: URL
  private let allowScaling: Bool
  var onDismiss: (() -> Void)?

  init(fileURL: URL, allowScaling: Bool) {
    self.fileURL = fileURL
    self.allowScaling = allowScaling
  }

  func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

  func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
    let item = ARQuickLookPreviewItem(fileAt: fileURL)
    item.allowsContentScaling = allowScaling
    return item
  }

  func previewControllerDidDismiss(_ controller: QLPreviewController) {
    onDismiss?()
  }
}
#endif
