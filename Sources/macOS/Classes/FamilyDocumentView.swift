import Cocoa

public class FamilyDocumentView: NSView {
  public override var isFlipped: Bool { return true }
  var subviewsInLayoutOrder = [NSScrollView]()

  weak var familyScrollView: FamilyScrollView?

  var scrollViews: [NSScrollView] {
    return subviews.compactMap { $0 as? NSScrollView }
  }

  deinit {
    subviewsInLayoutOrder.removeAll()
  }

  public override func addSubview(_ view: NSView) {
    // Remove wrapper view to avoid duplicates.
    (view.enclosingScrollView as? FamilyWrapperView)?.removeFromSuperview()

    if let backgrounds = familyScrollView?.backgrounds.values,
      backgrounds.contains(view) {
      super.addSubview(view)
      return
    }

    let subview = wrapViewIfNeeded(view)
    super.addSubview(subview)
  }

  public func insertSubview(_ view: View, at index: Int) {
    // Remove wrapper view to avoid duplicates.
    (view.enclosingScrollView as? FamilyWrapperView)?.removeFromSuperview()

    if let backgrounds = familyScrollView?.backgrounds.values,
      backgrounds.contains(view) {
      super.addSubview(view)
      return
    }

    let subview = wrapViewIfNeeded(view)
    if !subviews.contains(subview) {
      subviews.insert(subview, at: index)
    }
    rebuildSubviewsInLayoutOrder()
  }

  private func wrapViewIfNeeded(_ view: View) -> View {
    let subview: NSView

    switch view {
    case let scrollView as NSScrollView:
      subview = scrollView
    default:
      let wrapper = FamilyWrapperView(frame: view.frame,
                                      wrappedView: view)
      wrapper.parentDocumentView = self
      subview = wrapper
    }

    return subview
  }

  override public func didAddSubview(_ subview: NSView) {
    super.didAddSubview(subview)
    rebuildSubviewsInLayoutOrder()
    if let scrollView = subview as? NSScrollView {
      familyScrollView?.didAddScrollViewToContainer(scrollView)
    }
  }

  override public func willRemoveSubview(_ subview: NSView) {
    super.willRemoveSubview(subview)
    rebuildSubviewsInLayoutOrder(exceptSubview: subview)
    familyScrollView?.didRemoveScrollViewToContainer(subview)
  }

  override public func scroll(_ point: NSPoint) {
    super.scroll(point)
    familyScrollView?.layoutViews(withDuration: nil, force: false, completion: nil)
  }

  private func rebuildSubviewsInLayoutOrder(exceptSubview: View? = nil) {
    subviewsInLayoutOrder.removeAll()

    var filteredSubviews = [NSScrollView]()
    for case let scrollView as FamilyWrapperView in subviews {
      guard !(scrollView.view === exceptSubview) else { continue }
      filteredSubviews.append(scrollView)
    }
    subviewsInLayoutOrder = filteredSubviews
  }
}
