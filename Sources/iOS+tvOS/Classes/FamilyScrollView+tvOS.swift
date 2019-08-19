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
          frame.origin.x = padding.left
        }

        frame.size.width = self.frame.size.width - margins.left - margins.right
        frame.size.height = newHeight

        if scrollView.frame != frame && frame.intersects(documentVisibleRect) {
          scrollView.frame = frame
        }

        scrollView.frame.origin.y = yOffsetOfCurrentSubview

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

    var validRect = documentVisibleRect
    let validOffset = bounds.size.height * 4
    validRect.origin.y = max(self.contentOffset.y - validOffset, 0)
    validRect.size.height = bounds.size.height + validOffset
    var discardableRect = documentVisibleRect
    let discardOffset = bounds.size.height * 2
    discardableRect.origin.y = max(self.contentOffset.y - discardOffset, 0)
    discardableRect.size.height = bounds.size.height + discardOffset

    let validAttributes = getValidAttributes(in: validRect)
    for attributes in validAttributes where attributes.view.isHidden == false  {
      let scrollView = attributes.scrollView
      let padding = spaceManager.padding(for: attributes)
      var frame = scrollView.frame
      var contentOffset = scrollView.contentOffset

      if self.contentOffset.y < scrollView.frame.origin.y {
        contentOffset.y = 0.0
        frame.origin.y = round(scrollView.frame.origin.y)
      } else {
        contentOffset.y = self.contentOffset.y - scrollView.frame.origin.y
        frame.origin.y = round(self.contentOffset.y)
      }

      let remainingBoundsHeight = bounds.maxY - scrollView.frame.minY
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
        if scrollView.contentOffset.y != contentOffset.y && self.contentOffset.y < scrollView.frame.origin.y {
          scrollView.contentOffset.y = contentOffset.y
        } else {
          frame.origin.y = attributes.frame.origin.y
        }
      } else if shouldScroll {
        scrollView.contentOffset.y = contentOffset.y
      } else {
        frame.origin.y = attributes.origin.y
        // Reset content offset to avoid setting offsets that
        // look liked `clipsToBounds` bugs.
        if self.contentOffset.y < attributes.maxY {
          scrollView.contentOffset.y = 0
        }
      }

      if !attributes.frame.intersects(discardableRect) {
        newHeight = 0
      }

      frame.size.height = newHeight

      if scrollView.frame != frame {
        scrollView.frame = frame
      }
    }
  }
}
#endif
