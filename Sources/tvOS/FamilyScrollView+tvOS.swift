import UIKit

extension FamilyScrollView {
  /// The layout algorithm simply lays out the view in linear order vertically
  /// based on the views index inside `subviewsInLayoutOrder`. This is invoked
  /// when a view changes size or origin. It also scales the frame of scroll views
  /// in order to keep dequeuing for table and collection views.
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

        if scrollView is FamilyWrapperView {
          newHeight = fmin(documentView.frame.height, scrollView.contentSize.height)
        } else {
          newHeight = fmin(documentView.frame.height, newHeight)
        }

        if newHeight == 0 {
          newHeight = fmin(documentView.frame.height, scrollView.contentSize.height)
        }

        let shouldScroll = (self.contentOffset.y >= frame.origin.y &&
          self.contentOffset.y <= scrollView.frame.maxY) &&
          frame.height >= documentView.frame.height

        if shouldScroll {
          scrollView.contentOffset.y = contentOffset.y
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

        let remainingBoundsHeight = bounds.maxY - entry.origin.y
        let remainingContentHeight = entry.contentSize.height - contentOffset.y
        var newHeight: CGFloat = fmin(documentView.frame.height, scrollView.contentSize.height)

        if remainingBoundsHeight <= -self.frame.size.height {
          newHeight = 0
        }

        if remainingContentHeight <= -self.frame.size.height {
          newHeight = 0
        }

        let shouldScroll = (self.contentOffset.y > frame.origin.y &&
          self.contentOffset.y < entry.maxY) &&
          frame.height >= documentView.frame.height

        if shouldScroll {
          scrollView.contentOffset.y = contentOffset.y
        } else {
          frame.origin.y = entry.origin.y
        }

        frame.size.height = newHeight

        if compare(scrollView.frame.origin, to: frame.origin) ||
          compare(scrollView.frame.size, to: frame.size) {
          scrollView.frame = frame
        }
      }
    }
  }
}
