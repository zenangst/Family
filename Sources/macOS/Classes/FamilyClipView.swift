import Cocoa

class FamilyClipView: NSClipView {
  var wrapperView: FamilyWrapperView? { return enclosingScrollView as? FamilyWrapperView }
  var scrollView: FamilyScrollView? { return wrapperView?.enclosingScrollView as? FamilyScrollView }

  override func scroll(to newOrigin: NSPoint) {
    super.scroll(to: newOrigin)
    guard let familyScrollView = scrollView else { return }
    familyScrollView.isScrollingByProxy = true
    familyScrollView.scrollTo(newOrigin, in: documentView!)
  }
}
