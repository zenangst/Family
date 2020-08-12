import UIKit
import Family_Shared

/// This class is used to wrap views in `FamilyContentView` that don't inherit
/// from `UIScrollView`. This is done to ensure that the user gets a fluid and
/// smooth scrolling experience when scrolling in a `FamilyScrollView`.
class FamilyWrapperView: UIScrollView, ViewWrapper {
  weak var familyScrollView: FamilyScrollView?
  /// The wrapped view
  var view: UIView
  /// Observers the frame of the wrapped view.
  /// The frame size of the wrapped view is used for content size.
  private var frameObserver: NSKeyValueObservation?
  private var hiddenObserver: NSKeyValueObservation?

  /// Initializes and returns a newly allocated view object with the specified frame rectangle.
  /// The view that gets passed will be used as the wrapped view for the `FamilyWrapperView`.
  ///
  /// - Parameters:
  ///   - frame: The frame rectangle for the view, measured in points.
  ///   - view: The view that will be observered and used inside the wrapper.
  required init(frame: CGRect, view: UIView) {
    self.view = view
    super.init(frame: frame)
    // Disable resizing of subviews to avoid recursion.
    // The wrapper view should follow the `.view`'s size, not the
    // otherway around. If this is set to `true` then there is
    // a potential for the observers trigger a resizing recursion.
    autoresizesSubviews = false
    addSubview(view)
    alwaysBounceVertical = true
    clipsToBounds = false
    if #available(iOS 11.0, tvOS 11.0, *) {
      contentInsetAdjustmentBehavior = .never
    }

    configureObservers()
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  deinit {
    frameObserver?.invalidate()
    hiddenObserver?.invalidate()
  }

  private func configureObservers() {
    frameObserver = view.observe(\.frame, options: [.initial, .new, .old]) { [weak self] (view, value) in
      if let rect = value.newValue, rect != value.oldValue {
        self?.setWrapperFrameSize(rect)
      }
    }

    hiddenObserver = view.observe(\.isHidden, options: [.initial, .new, .old]) { [weak self] (_, value) in
      if value.newValue != value.oldValue, let newValue = value.newValue {
        self?.isHidden = newValue
        self?.familyScrollView?.setNeedsLayout()
        self?.familyScrollView?.layoutIfNeeded()
      }
    }
  }

  /// Sets the size of the rectangle as the content size for the view.
  /// This is called inside the observer that check for changes to the `.view`'s frame.
  ///
  /// - Parameter rect: The frame rectangle for the view, measured in points.
  ///                   This is the frame of the view that is wrapped inside the view.
  private func setWrapperFrameSize(_ rect: CGRect) {
    frame.size = rect.size
    contentSize = rect.size
  }
}
