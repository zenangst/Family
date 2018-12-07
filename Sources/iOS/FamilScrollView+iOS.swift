import UIKit

extension FamilyScrollView {
  internal func runLayoutSubviewsAlgorithm() {
    if cache.isEmpty {
      var yOffsetOfCurrentSubview: CGFloat = 0.0
      for scrollView in subviewsInLayoutOrder where scrollView.isHidden == false {
        let view = (scrollView as? FamilyWrapperView)?.view ?? scrollView
        let insets = spaceManager.customInsets(for: view)
        if (scrollView as? FamilyWrapperView)?.view.isHidden == true {
          continue
        }

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

        //        frame.size.width = max(frame.size.width, self.frame.size.width)
        if scrollView is FamilyWrapperView {
          newHeight = fmin(documentView.frame.height, scrollView.contentSize.height)
        } else {
          newHeight = fmin(documentView.frame.height, newHeight)
        }

        let shouldModifyContentOffset = contentOffset.y <= scrollView.contentSize.height ||
          self.contentOffset.y != frame.minY

        if shouldModifyContentOffset {
          if !compare(scrollView.contentOffset, to: contentOffset) {
            scrollView.contentOffset.y = contentOffset.y
          }
        } else {
          frame.origin.y = yOffsetOfCurrentSubview
        }

        frame.size.width = self.frame.size.width - insets.left - insets.right
        frame.size.height = newHeight

        if scrollView.frame != frame {
          scrollView.frame = frame
        }

        yOffsetOfCurrentSubview += scrollView.contentSize.height + insets.bottom + insets.top
        var cachedOrigin = frame.origin
        cachedOrigin.y += insets.top
        cache.add(entry: FamilyCacheEntry(view: view,
                                          origin: cachedOrigin,
                                          contentSize: scrollView.contentSize))
      }
      computeContentSize()
    } else {
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
          frame.origin.y = floor(entry.origin.y)
        } else {
          contentOffset.y = self.contentOffset.y - entry.origin.y
          frame.origin.y = floor(self.contentOffset.y)
        }

        let remainingBoundsHeight = fmax(bounds.maxY - entry.origin.y, 0.0)
        let remainingContentHeight = fmax(scrollView.contentSize.height - contentOffset.y, 0.0)
        var newHeight: CGFloat = ceil(fmin(remainingBoundsHeight, remainingContentHeight))

        if scrollView is FamilyWrapperView {
          newHeight = fmin(documentView.frame.height, scrollView.contentSize.height)
        } else {
          newHeight = fmin(documentView.frame.height, newHeight)
        }

        let shouldScroll = self.contentOffset.y >= entry.origin.y && self.contentOffset.y <= entry.maxY

        if shouldScroll {
          scrollView.contentOffset.y = contentOffset.y
        }

        frame.size.height = newHeight

        if scrollView.frame != frame {
          scrollView.frame = frame
        }
      }
    }
  }
}
