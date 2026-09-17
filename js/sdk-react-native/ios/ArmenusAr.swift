import ARKit
import Foundation
import QuickLook
import React
import UIKit

/**
 AR placement, via the system viewer.

 There is no ARKit code here and there should not be. `QLPreviewController` in
 AR mode *is* ARKit — plane detection, real-world scale, people occlusion,
 contact shadows, and the drag/rotate/scale gestures every iPhone user already
 knows. Hand-rolling an ARSCNView equivalent means reimplementing all of that,
 arriving somewhere worse, and diverging from the AR interaction the user has
 seen in Safari, Messages and the App Store.

 The one thing Quick Look will not do is fetch a remote file, which is why the
 cache exists and why `prefetch` is worth calling before the button is tapped.
 */
@objc(ArmenusAr)
public final class ArmenusAr: NSObject {

  @objc public static func requiresMainQueueSetup() -> Bool { true }

  /**
   Whether this handset can do AR at all.

   `ARWorldTrackingConfiguration.isSupported` is the real test — A9 and later.
   Checking the iOS version instead is the common mistake and is wrong: an
   iPhone 6 on iOS 15 passes a version check and has no world tracking.
   */
  @objc(isArAvailable:reject:)
  public func isArAvailable(
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) {
    resolve(ARWorldTrackingConfiguration.isSupported)
  }

  @objc(prefetch:resolve:reject:)
  public func prefetch(
    url: String,
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) {
    ArmenusModelCache.shared.file(for: url) { local, error in
      if let local {
        resolve(local.path)
      } else {
        reject("prefetch_failed", error?.localizedDescription ?? "Download failed", error)
      }
    }
  }

  @objc(presentAr:resolve:reject:)
  public func presentAr(
    options: NSDictionary,
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) {
    guard let urlString = options["url"] as? String else {
      reject("bad_args", "url is required", nil)
      return
    }
    let title = options["title"] as? String ?? ""
    let allowScaling = options["allowScaling"] as? Bool ?? false

    ArmenusModelCache.shared.file(for: urlString) { local, error in
      guard let local else {
        reject("download_failed", error?.localizedDescription ?? "Download failed", error)
        return
      }

      DispatchQueue.main.async {
        guard let presenter = Self.topViewController() else {
          reject("no_presenter", "No view controller to present from", nil)
          return
        }

        let controller = QLPreviewController()
        let source = ArmenusPreviewSource(
          fileUrl: local, title: title, allowScaling: allowScaling)
        controller.dataSource = source
        controller.delegate = source

        // The data source is held weakly by QLPreviewController, so without
        // this it deallocates immediately and the preview opens blank.
        Self.retainedSource = source
        source.onDismiss = {
          Self.retainedSource = nil
          resolve(nil)
        }

        presenter.present(controller, animated: true)
      }
    }
  }

  @objc(cacheSize:reject:)
  public func cacheSize(
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) {
    resolve(NSNumber(value: ArmenusModelCache.shared.totalBytes()))
  }

  @objc(clearCache:reject:)
  public func clearCache(
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) {
    ArmenusModelCache.shared.clear()
    resolve(nil)
  }

  private static var retainedSource: ArmenusPreviewSource?

  /**
   The controller to present from.

   Walks presented controllers rather than using `rootViewController` directly:
   in a real app the dish card is usually already inside a presented modal, and
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
 Bridges the file to Quick Look, and carries the AR-specific options.

 `ARQuickLookPreviewItem` rather than the plain file URL: it is the only way to
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
    if !title.isEmpty { item.canonicalWebPageURL = nil }
    return item
  }

  func previewControllerDidDismiss(_ controller: QLPreviewController) {
    onDismiss?()
  }
}
