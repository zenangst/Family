import Cocoa

class FamilyClipView: NSClipView {

  override func scroll(to newOrigin: NSPoint) {
    super.scroll(to: newOrigin)
    guard let wrapperView = enclosingScrollView as? FamilyWrapperView,
      let familyScrollView = wrapperView.enclosingScrollView as? FamilyScrollView else {
        return
    }

    familyScrollView.scrollTo(newOrigin, in: documentView!)
  }
}
