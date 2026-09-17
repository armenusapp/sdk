#if os(iOS)
import SwiftUI

/// A dish in 3D, with AR where the handset supports it. SwiftUI.
///
/// Wraps ``ArmenusModelView``. The view is square plus an optional one-line
/// note beneath it, so give it a width and let it size its height.
///
/// ```swift
/// ArmenusModel(item: item, arLabel: "See it on your table")
/// ```
@available(iOS 15, *)
public struct ArmenusModel: UIViewRepresentable {
  public var item: EmbedItem?
  public var arLabel: String
  /// Pass false inside a `List` or `ScrollView` row so vertical drags reach
  /// the scroll view instead of rotating the dish.
  public var interactionEnabled: Bool
  public var onEnterAR: ((EmbedItem) -> Void)?
  public var onError: ((String) -> Void)?

  public init(
    item: EmbedItem?,
    arLabel: String = "View on your table",
    interactionEnabled: Bool = true,
    onEnterAR: ((EmbedItem) -> Void)? = nil,
    onError: ((String) -> Void)? = nil
  ) {
    self.item = item
    self.arLabel = arLabel
    self.interactionEnabled = interactionEnabled
    self.onEnterAR = onEnterAR
    self.onError = onError
  }

  public func makeUIView(context: Context) -> ArmenusModelView {
    let view = ArmenusModelView()
    view.setContentHuggingPriority(.defaultLow, for: .horizontal)
    return view
  }

  public func updateUIView(_ view: ArmenusModelView, context: Context) {
    view.arLabel = arLabel
    view.interactionEnabled = interactionEnabled
    view.onEnterAR = onEnterAR
    view.onModelError = onError
    if view.item != item {
      view.display(item)
    }
  }

  @available(iOS 16.0, *)
  public func sizeThatFits(_ proposal: ProposedViewSize, uiView: ArmenusModelView, context: Context) -> CGSize? {
    guard let width = proposal.width, width.isFinite else { return nil }
    let fitting = uiView.systemLayoutSizeFitting(
      CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
      withHorizontalFittingPriority: .required,
      verticalFittingPriority: .fittingSizeLevel)
    return CGSize(width: width, height: fitting.height)
  }
}
#endif
