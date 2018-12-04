import Cocoa

public class FamilyDocumentView: NSView {
  public override var isFlipped: Bool { return true }

  weak var familyScrollView: FamilyScrollView?

  var scrollViews: [NSScrollView] {
    return subviews.compactMap { $0 as? NSScrollView }
  }

  public override func addSubview(_ view: NSView) {
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
    super.addSubview(subview)
  }

  override public func didAddSubview(_ subview: NSView) {
    super.didAddSubview(subview)
    if let scrollView = subview as? NSScrollView {
      familyScrollView?.didAddScrollViewToContainer(scrollView)
    }
  }

  override public func willRemoveSubview(_ subview: NSView) {
    super.willRemoveSubview(subview)
    familyScrollView?.didRemoveScrollViewToContainer(subview)
  }

  override public func scroll(_ point: NSPoint) {
    super.scroll(point)
    familyScrollView?.layoutViews()
  }
}
