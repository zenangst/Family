#if os(iOS)
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
          frame.origin.y = round(yOffsetOfCurrentSubview)
        } else {
          contentOffset.y = self.contentOffset.y - yOffsetOfCurrentSubview
          frame.origin.y = round(self.contentOffset.y)
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

        cache.add(entry: FamilyViewControllerAttributes(view: view,
                                                        origin: CGPoint(x: frame.origin.x,
                                                                        y: yOffsetOfCurrentSubview),
                                                        contentSize: scrollView.contentSize))
        yOffsetOfCurrentSubview += scrollView.contentSize.height + insets.bottom
      }
      cache.contentSize = computeContentSize()
      cache.state = .isFinished
      contentSize = cache.contentSize
    }

    for (offset, scrollView) in subviewsInLayoutOrder.enumerated() where scrollView.isHidden == false {
      let view = (scrollView as? FamilyWrapperView)?.view ?? scrollView
      guard let entry = cache.entry(for: view) else { continue }
      if (scrollView as? FamilyWrapperView)?.view.isHidden == true {
        continue
      }

      var frame = scrollView.frame
      var contentOffset = scrollView.contentOffset

      if self.contentOffset.y < entry.origin.y {
        contentOffset.y = 0.0
        frame.origin.y = abs(round(entry.origin.y))
      } else {
        contentOffset.y = self.contentOffset.y - entry.origin.y
        frame.origin.y = abs(round(self.contentOffset.y))
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

      if scrollView is FamilyWrapperView {
        if self.contentOffset.y < entry.origin.y {
          scrollView.contentOffset.y = contentOffset.y
        } else {
          frame.origin.y = entry.origin.y
        }
      } else if shouldScroll {
        scrollView.contentOffset.y = contentOffset.y
      } else {
        frame.origin.y = entry.origin.y

        // Reset content offset to avoid setting offsets that
        // look liked `clipsToBounds` bugs.
        if self.contentOffset.y < entry.maxY && scrollView.contentOffset.y != 0 {
          scrollView.contentOffset.y = 0
        }
      }

      frame.size.height = newHeight

      if scrollView.frame != frame {
        scrollView.frame = frame
      }
    }
  }
}
#endif
