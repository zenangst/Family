import Cocoa

public class FamilyContentView: NSView {
  public override var isFlipped: Bool { return true }

  var scrollViews: [NSScrollView] {
    return subviews.flatMap { $0 as? NSScrollView }
  }

  public override func addSubview(_ view: NSView) {
    let subview: NSView

    switch view {
    case let scrollView as NSScrollView:
      subview = scrollView
    default:
      let wrapper = FamilyWrapperView(frame: view.frame,
                                      wrappedView: view)
      subview = wrapper
    }
    super.addSubview(subview)
  }

  override public func didAddSubview(_ subview: NSView) {
    super.didAddSubview(subview)
    resolveFamilyScrollView {
      if let scrollView = subview as? NSScrollView {
        $0.didAddScrollViewToContainer(scrollView)
      }
    }
  }

  override public func willRemoveSubview(_ subview: NSView) {
    resolveFamilyScrollView { $0.willRemoveSubview(subview) }
  }

  override public func scroll(_ point: NSPoint) {
    super.scroll(point)
    resolveFamilyScrollView { $0.layoutViews() }
  }

  private func resolveFamilyScrollView(closure: (FamilyScrollView) -> Void) {
    if let familyScrollView = enclosingScrollView as? FamilyScrollView {
      closure(familyScrollView)
    }
  }
}
