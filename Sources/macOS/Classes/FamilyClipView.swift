import Cocoa

class FamilyClipView: NSClipView {
  override var isFlipped: Bool { return true }
  var wrapperView: FamilyWrapperView? { return enclosingScrollView as? FamilyWrapperView }
  var scrollView: FamilyScrollView? { return wrapperView?.enclosingScrollView as? FamilyScrollView }

  override func scroll(to newOrigin: NSPoint) {
    super.scroll(to: newOrigin)
    guard let familyScrollView = scrollView else { return }
    familyScrollView.isScrollingByProxy = true
    familyScrollView.scrollTo(newOrigin, in: documentView!)
  }
}

fileprivate extension NSCollectionView {
  var isHorizontal: Bool {
    return (collectionViewLayout as? NSCollectionViewFlowLayout)?.scrollDirection == .horizontal
  }
}

fileprivate extension NSScrollView {
  var isHorizontal: Bool {
    return (documentView as? NSCollectionView)?.isHorizontal ?? false
  }
}
