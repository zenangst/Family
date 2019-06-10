import UIKit

protocol FamilyDocumentViewDelegate: class {
  func familyDocumentView(_ view: FamilyDocumentView, didAddScrollView scrollView: UIScrollView)
}

/// This classes acts as a view container for `FamilyScrollView`.
/// It is used to wrap views that don't inherit from `UIScrollView`
/// in `FamilyWrapperView`'s. This is done so that the `FamilyScrollView`
/// only needs to take `UIScrollView` based views into account when performing
/// its layout algorithm.
public class FamilyDocumentView: UIView {
  weak var delegate: FamilyDocumentViewDelegate?
  weak var familyScrollView: FamilyScrollView?

  /// Convenience methods to return all subviews as scroll view.
  var scrollViews: [UIScrollView] {
    return subviews.compactMap { $0 as? UIScrollView }
  }

  public override init(frame: CGRect) {
    super.init(frame: frame)
    autoresizesSubviews = false
  }
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  /// Adds a view to the end of the receiver’s list of subviews.
  /// If view do not inherit from `UIScrollView`, the view will be
  /// wrapped in a `FamilyWrapperView` that works as a scroll view
  /// for the view.
  ///
  /// - Parameter view: The view to be added.
  ///                   After being added, this view appears on top of any other subviews.
  open override func addSubview(_ view: UIView) {
    let subview = wrapViewIfNeeded(view)
    super.addSubview(subview)

    guard let scrollView = subview as? UIScrollView else { return }

    delegate?.familyDocumentView(self, didAddScrollView: scrollView)
    purgeViews()
  }

  public override func insertSubview(_ view: UIView, at index: Int) {
    let subview = wrapViewIfNeeded(view)
    super.insertSubview(subview, at: index)
    guard let scrollView = subview as? UIScrollView else { return }
    delegate?.familyDocumentView(self, didAddScrollView: scrollView)
    purgeViews()
  }

  private func wrapViewIfNeeded(_ view: UIView) -> UIView {
    let subview: UIView

    switch view {
    case let scrollView as UIScrollView:
      subview = scrollView
    default:
      let wrapper = FamilyWrapperView(frame: view.frame,
                                      view: view)
      wrapper.parentDocumentView = self
      subview = wrapper
    }

    return subview
  }

  private func purgeViews() {
    for case let wrapperView as FamilyWrapperView in subviews {
      if wrapperView.view.superview != wrapperView {
        wrapperView.removeFromSuperview()
      }
    }
  }

  /// Tells the view that a subview is about to be removed.
  /// Calls `FamilyScrollView` in order to remove the observers
  /// on the view.
  ///
  /// - Parameter subview: The subview that will be removed.
  override open func willRemoveSubview(_ subview: UIView) {
    super.willRemoveSubview(subview)
    familyScrollView?.willRemoveSubview(subview)
  }

  /// Lays out subviews.
  open override func layoutSubviews() {
    super.layoutSubviews()
    familyScrollView?.setNeedsLayout()
  }
}

