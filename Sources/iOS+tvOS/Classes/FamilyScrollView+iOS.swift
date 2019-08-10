#if os(iOS)
import UIKit

extension FamilyScrollView {
  internal func runLayoutSubviewsAlgorithm() {
    guard cache.state != .isRunning else { return }

    if cache.state == .empty {
      cache.state = .isRunning
      var yOffsetOfCurrentSubview: CGFloat = 0.0
      for scrollView in subviewsInLayoutOrder where scrollView.isHidden == false {
        if (scrollView as? FamilyWrapperView)?.view.isHidden == true {
          continue
        }

        let view = (scrollView as? FamilyWrapperView)?.view ?? scrollView
        let padding = spaceManager.padding(for: view)
        let margins = spaceManager.margins(for: view)

        yOffsetOfCurrentSubview += margins.top

        var frame = scrollView.frame
        var contentOffset = scrollView.contentOffset

        if self.contentOffset.y < yOffsetOfCurrentSubview {
          contentOffset.y = 0.0
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
          frame.origin.x = margins.left
        } else {
          newHeight = fmin(documentView.frame.height, newHeight)
          frame.origin.x = margins.left + padding.left
        }

        frame.size.width = self.frame.size.width - margins.left - margins.right
        frame.size.height = newHeight

        if scrollView.frame != frame {
          scrollView.frame = frame
        }

        cache.add(entry: FamilyViewControllerAttributes(view: view,
                                                        origin: CGPoint(x: frame.origin.x,
                                                                        y: yOffsetOfCurrentSubview + padding.top),
                                                        contentSize: scrollView.contentSize))

        if let backgroundView = backgrounds[view] {
          frame.origin.y = yOffsetOfCurrentSubview
          positionBackgroundView(scrollView, frame, margins, padding, backgroundView, view)
        }

        if scrollView.contentSize.height > 0 {
          yOffsetOfCurrentSubview += scrollView.contentSize.height + margins.bottom + padding.top + padding.bottom
        }
      }

      let computedHeight = yOffsetOfCurrentSubview
      let minimumContentHeight = bounds.height - (contentInset.top + contentInset.bottom)
      var height = fmax(computedHeight, minimumContentHeight)
      cache.contentSize = CGSize(width: bounds.size.width, height: yOffsetOfCurrentSubview)

      if isChildViewController {
        height = computedHeight
        superview?.frame.size.height = cache.contentSize.height
      }

      cache.state = .isFinished
      contentSize = CGSize(width: cache.contentSize.width, height: height)
    }

    for attributes in validAttributes() where attributes.view.isHidden == false  {
      let scrollView = attributes.scrollView
      let padding = spaceManager.padding(for: attributes)
      var frame = scrollView.frame
      var contentOffset = scrollView.contentOffset

      if self.contentOffset.y < attributes.origin.y {
        contentOffset.y = 0.0
        frame.origin.y = abs(round(attributes.origin.y))
      } else {
        contentOffset.y = self.contentOffset.y - attributes.origin.y
        frame.origin.y = abs(round(self.contentOffset.y))
      }

      let remainingBoundsHeight = bounds.maxY - attributes.origin.y
      let remainingContentHeight = attributes.contentSize.height - contentOffset.y
      var newHeight: CGFloat = fmin(documentView.frame.height, scrollView.contentSize.height)

      if remainingBoundsHeight <= -self.frame.size.height {
        newHeight = 0
      }

      if remainingContentHeight <= -self.frame.size.height {
        newHeight = 0
      }

      if newHeight > 0 {
        newHeight += padding.top + padding.bottom
      }

      let shouldScroll = (round(self.contentOffset.y) >= round(frame.origin.y) &&
        round(self.contentOffset.y) < round(attributes.maxY)) &&
        round(frame.height) >= round(documentView.frame.height)

      if scrollView is FamilyWrapperView {
        if self.contentOffset.y < attributes.origin.y {
          scrollView.contentOffset.y = contentOffset.y
        } else {
          frame.origin.y = attributes.origin.y
        }
      } else if shouldScroll {
        scrollView.contentOffset.y = contentOffset.y
      } else {
        frame.origin.y = attributes.origin.y

        // Reset content offset to avoid setting offsets that
        // look liked `clipsToBounds` bugs.
        if self.contentOffset.y < attributes.maxY && scrollView.contentOffset.y != 0 {
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
