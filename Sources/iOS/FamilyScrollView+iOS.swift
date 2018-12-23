import UIKit

extension FamilyScrollView {
  internal func runLayoutSubviewsAlgorithm() {
    guard cache.state != .isRunning else { return }

    if cache.state == .empty {
      cache.state = .isRunning
      var yOffsetOfCurrentSubview: CGFloat = 0.0
      for scrollView in subviewsInLayoutOrder where scrollView.isHidden == false {
        let view = (scrollView as? FamilyWrapperView)?.view ?? scrollView
        let insets = spaceManager.customInsets(for: view)
        if (scrollView as? FamilyWrapperView)?.view.isHidden == true {
          continue
        }

        yOffsetOfCurrentSubview += insets.top

        var frame = scrollView.frame
        var contentOffset = scrollView.contentOffset

        if self.contentOffset.y < yOffsetOfCurrentSubview {
          contentOffset.y = insets.top
          frame.origin.y = floor(yOffsetOfCurrentSubview)
        } else {
          contentOffset.y = self.contentOffset.y - yOffsetOfCurrentSubview
          frame.origin.y = floor(self.contentOffset.y)
        }

        let remainingBoundsHeight = fmax(bounds.maxY - yOffsetOfCurrentSubview, 0.0)
        let remainingContentHeight = fmax(scrollView.contentSize.height - contentOffset.y, 0.0)
        var newHeight: CGFloat = ceil(fmin(remainingBoundsHeight, remainingContentHeight))

        if scrollView is FamilyWrapperView {
          newHeight = fmin(documentView.frame.height, scrollView.contentSize.height)
        } else {
          newHeight = fmin(documentView.frame.height, newHeight)
        }

        frame.origin.y = yOffsetOfCurrentSubview
        frame.origin.x = insets.left
        frame.size.width = self.frame.size.width - insets.left - insets.right
        frame.size.height = newHeight

        if scrollView.frame != frame {
          scrollView.frame = frame
        }

        cache.add(entry: FamilyCacheEntry(view: view,
                                          origin: CGPoint(x: frame.origin.x,
                                                          y: yOffsetOfCurrentSubview),
                                          contentSize: scrollView.contentSize))
        yOffsetOfCurrentSubview += scrollView.contentSize.height + insets.bottom
      }
      computeContentSize()
      cache.state = .isFinished
    }

    for scrollView in subviewsInLayoutOrder where scrollView.isHidden == false {
      let view = (scrollView as? FamilyWrapperView)?.view ?? scrollView
      guard let entry = cache.entry(for: view) else { continue }
      if (scrollView as? FamilyWrapperView)?.view.isHidden == true {
        continue
      }

      var frame = scrollView.frame
      var contentOffset = scrollView.contentOffset

      if self.contentOffset.y < entry.origin.y {
        contentOffset.y = 0.0
        frame.origin.y = abs(entry.origin.y)
      } else {
        contentOffset.y = self.contentOffset.y - entry.origin.y
        frame.origin.y = abs(self.contentOffset.y)
      }

      let remainingBoundsHeight = fmax(bounds.maxY - entry.origin.y, 0.0)
      let remainingContentHeight = fmax(scrollView.contentSize.height - contentOffset.y, 0.0)
      var newHeight: CGFloat = ceil(fmin(remainingBoundsHeight, remainingContentHeight))

      if scrollView is FamilyWrapperView {
        newHeight = fmin(documentView.frame.height, scrollView.contentSize.height)
      } else {
        newHeight = fmin(documentView.frame.height, newHeight)
      }

      let shouldScroll = self.contentOffset.y >= entry.origin.y &&
        self.contentOffset.y <= entry.maxY &&
        scrollView.contentOffset.y == abs(contentOffset.y)

      if shouldScroll || scrollView is FamilyWrapperView {
        scrollView.contentOffset.y = abs(contentOffset.y)
      }

      frame.size.height = newHeight

      if scrollView.frame != frame {
        scrollView.frame = frame
      }
    }

  }
}
