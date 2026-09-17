import React
import UIKit

/**
 Constructs the SceneKit preview and wires its callbacks to React.

 Split from the `.mm` registration because the view itself is Swift: the
 Objective-C++ file declares the props, this class creates the instance and
 bridges the two event blocks.
 */
@objc(ArmenusModelViewManager)
final class ArmenusModelViewManager: RCTViewManager {

  override func view() -> UIView! {
    let view = ArmenusModelViewBridge()
    return view
  }

  override static func requiresMainQueueSetup() -> Bool { true }
}

/**
 Adapter that exposes React's `RCTDirectEventBlock` props as the plain
 closures `ArmenusModelView` takes, so the renderer itself has no React
 dependency and stays testable on its own.
 */
@objc(ArmenusModelViewBridge)
final class ArmenusModelViewBridge: ArmenusModelView {

  @objc var onModelLoad: RCTDirectEventBlock? {
    didSet {
      super.onModelLoad = { [weak self] in
        self?.onModelLoad?([:])
      }
    }
  }

  @objc var onModelError: RCTDirectEventBlock? {
    didSet {
      super.onModelError = { [weak self] message in
        self?.onModelError?(["message": message])
      }
    }
  }
}
