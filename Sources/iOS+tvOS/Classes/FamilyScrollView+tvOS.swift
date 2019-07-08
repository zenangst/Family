#if os(tvOS)
import UIKit

extension FamilyScrollView {
  /// The layout algorithm simply lays out the view in linear order vertically
  /// based on the views index inside `subviewsInLayoutOrder`. This is invoked
  /// when a view changes size or origin. It also scales the frame of scroll views
  /// in order to keep dequeuing for table and collection views.
  internal func runLayoutSubviewsAlgorithm() {
    guard cache.state != .isRunning else { return }

    if cache.state == .empty {
      cache.state = .isRunning
      var yOffsetOfCurrentSubview: CGFloat = 0.0
      for scrollView in subviewsInLayoutOrder where scrollView.isHidden == false {
        let view = (scrollView as? FamilyWrapperView)?.view ?? scrollView
        let padding = spaceManager.padding(for: view)
        let margins = spaceManager.margins(for: view)
        if (scrollView as? FamilyWrapperView)?.view.isHidden == true {
          continue
        }

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
          frame.origin.x = padding.left
        }

        frame.size.width = self.frame.size.width - margins.left - margins.right
        frame.size.height = newHeight

        if newHeight == 0 {
          newHeight = fmin(documentView.frame.height, scrollView.contentSize.height)
        }

        if scrollView.frame != frame {
          scrollView.frame = frame
        }

        cache.add(entry: FamilyViewControllerAttributes(view: view,
                                                        origin: CGPoint(x: frame.origin.x,
                                                                        y: yOffsetOfCurrentSubview),
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
        frame.origin.y = round(entry.origin.y)
      } else {
        contentOffset.y = self.contentOffset.y - entry.origin.y
        frame.origin.y = round(self.contentOffset.y)
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
        if self.contentOffset.y < entry.maxY {
          scrollView.contentOffset.y = 0
        }
      }

      frame.size.height = newHeight

      if compare(scrollView.frame.origin, to: frame.origin) ||
        compare(scrollView.frame.size, to: frame.size) {
        scrollView.frame = frame
      }
    }

  }
}
#endif
