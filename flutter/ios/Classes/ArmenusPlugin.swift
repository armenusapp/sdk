import ARKit
import Flutter
import QuickLook
import UIKit

/**
 Flutter entry point: the AR channel and the platform-view factory.

 Mirrors the React Native SDK deliberately — same cache, same Quick Look
 presentation, same SceneKit preview — so a partner shipping both apps gets one
 behaviour rather than two that drift.
 */
public class ArmenusPlugin: NSObject, FlutterPlugin {

  private static var retainedSource: ArmenusPreviewSource?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "app.armenus/ar", binaryMessenger: registrar.messenger())
    let instance = ArmenusPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)

    registrar.register(
      ArmenusModelViewFactory(messenger: registrar.messenger()),
      withId: "app.armenus/model-view")
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isArAvailable":
      /*
       `ARWorldTrackingConfiguration.isSupported` is the real test — A9 and
       later. An iOS-version check is the common mistake and is wrong: an
       iPhone 6 on iOS 15 passes it and has no world tracking.
       */
      result(ARWorldTrackingConfiguration.isSupported)

    case "prefetch":
      guard let args = call.arguments as? [String: Any],
        let url = args["url"] as? String
      else {
        result(FlutterError(code: "bad_args", message: "url is required", details: nil))
        return
      }
      ArmenusModelCache.shared.file(for: url) { local, error in
        if let local {
          result(local.path)
        } else {
          result(
            FlutterError(
              code: "prefetch_failed",
              message: error?.localizedDescription ?? "Download failed",
              details: nil))
        }
      }

    case "presentAr":
      presentAr(call, result)

    case "cacheSize":
      result(Int(ArmenusModelCache.shared.totalBytes()))

    case "clearCache":
      ArmenusModelCache.shared.clear()
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /**
   Presents the system AR viewer.

   No ARKit code, on purpose: `QLPreviewController` in AR mode *is* ARKit —
   plane detection, real-world scale, people occlusion, contact shadows, and
   the gestures every iPhone user already knows from Safari and Messages.
   Hand-rolling an ARSCNView equivalent means reimplementing all of it and
   landing somewhere worse and less familiar.
   */
  private func presentAr(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
      let urlString = args["url"] as? String
    else {
      result(FlutterError(code: "bad_args", message: "url is required", details: nil))
      return
    }
    let title = args["title"] as? String ?? ""
    let allowScaling = args["allowScaling"] as? Bool ?? false

    // Quick Look will not read a remote URL, which is why the cache exists and
    // why `prefetch` before the button is tapped is worth doing.
    ArmenusModelCache.shared.file(for: urlString) { local, error in
      guard let local else {
        result(
          FlutterError(
            code: "download_failed",
            message: error?.localizedDescription ?? "Download failed",
            details: nil))
        return
      }

      DispatchQueue.main.async {
        guard let presenter = Self.topViewController() else {
          result(
            FlutterError(
              code: "no_presenter", message: "No view controller to present from",
              details: nil))
          return
        }

        let controller = QLPreviewController()
        let source = ArmenusPreviewSource(
          fileUrl: local, title: title, allowScaling: allowScaling)
        controller.dataSource = source
        controller.delegate = source

        // QLPreviewController holds its data source weakly, so without this it
        // deallocates immediately and the preview opens blank.
        Self.retainedSource = source
        source.onDismiss = {
          Self.retainedSource = nil
          result(nil)
        }

        presenter.present(controller, animated: true)
      }
    }
  }

  /**
   Walks presented controllers rather than using `rootViewController`.

   In a real app the dish card is usually already inside a presented route, and
   presenting from the root there throws "already presenting" and nothing
   happens.
   */
  private static func topViewController() -> UIViewController? {
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

/**
 Bridges the file to Quick Look and carries the AR options.

 `ARQuickLookPreviewItem` rather than a plain file URL: it is the only way to
 set `allowsContentScaling`, and turning that off is what keeps the dish at the
 size it actually is instead of whatever the user last pinched it to.
 */
final class ArmenusPreviewSource: NSObject, QLPreviewControllerDataSource,
  QLPreviewControllerDelegate
{
  private let fileUrl: URL
  private let title: String
  private let allowScaling: Bool
  var onDismiss: (() -> Void)?

  init(fileUrl: URL, title: String, allowScaling: Bool) {
    self.fileUrl = fileUrl
    self.title = title
    self.allowScaling = allowScaling
  }

  func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

  func previewController(
    _ controller: QLPreviewController, previewItemAt index: Int
  ) -> QLPreviewItem {
    let item = ARQuickLookPreviewItem(fileAt: fileUrl)
    item.allowsContentScaling = allowScaling
    return item
  }

  func previewControllerDidDismiss(_ controller: QLPreviewController) {
    onDismiss?()
  }
}
