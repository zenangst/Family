import UIKit

public final class FamilyScrollView: UIScrollView, UIGestureRecognizerDelegate {
  /// The amount of spacing that should be inserted inbetween views.
  public var spacingBetweenViews: CGFloat = 0
  /// A collection of scroll views that is used to order the views on screen.
  /// This collection is used by the layout algorithm that render the views and
  /// the order that they should appear.
  public var subviewsInLayoutOrder = [UIScrollView]()
  /// Observer is a simple struct wrapper that holds the view that gets observed
  /// together with the key value observeration object. This is used to resolve
  /// and remove the correct observeration when views get add to the view hierarcy.
  private struct Observer: Equatable {
    let view: UIView
    let keyValueObservation: NSKeyValueObservation

    static func == (lhs: Observer, rhs: Observer) -> Bool {
      return lhs.view === rhs.view && lhs.keyValueObservation === rhs.keyValueObservation
    }
  }

  /// A collection of observers connected to the observed views.
  /// See `observeView` methods for more information about which
  /// properties that get observed.
  private var observers = [Observer]()

  /// The custom distance that the content view is inset from the safe area or scroll view edges.
  open override var contentInset: UIEdgeInsets {
    willSet {
      if self.isTracking {
        let diff = newValue.top - self.contentInset.top
        var translation = self.panGestureRecognizer.translation(in: self)
        translation.y -= diff * 3.0 / 2.0
        self.panGestureRecognizer.setTranslation(translation, in: self)
      }
    }
  }

  /// The content view is where all views get added when a view is used
  /// in the `Family` framework.
  public var contentView: FamilyContentView = FamilyContentView()

  deinit {
    subviewsInLayoutOrder.removeAll()
    observers.removeAll()
  }

  /// Initializes and returns a newly allocated view object with the specified frame rectangle.
  ///
  /// - Parameter frame: The frame rectangle for the view, measured in points.
  public required override init(frame: CGRect) {
    super.init(frame: frame)
    contentView.autoresizingMask = self.autoresizingMask
    if #available(iOS 11.0, tvOS 11.0, *) {
      contentInsetAdjustmentBehavior = .never
    }
    addSubview(contentView)
  }

  required public init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  /// Tells the view that its superview changed.
  open override func didMoveToSuperview() {
    super.didMoveToSuperview()

    guard let superview = superview else {
      return
    }

    if frame.size.height != superview.frame.size.height {
      frame.size.height = superview.frame.size.height
    }
  }

  /// This configures observers and configures the scroll views
  /// that gets added to the view heirarcy. See `observeView` for
  /// more information about which properties that get observed.
  ///
  /// - Parameter scrollView: The scroll view that should be configured
  ///                         and observed.
  func didAddScrollViewToContainer(_ scrollView: UIScrollView) {
    scrollView.autoresizingMask = UIViewAutoresizing()

    guard contentView.subviews.index(of: scrollView) != nil else {
      return
    }

    observeView(view: scrollView)

    subviewsInLayoutOrder.removeAll()
    for scrollView in contentView.scrollViews {
      subviewsInLayoutOrder.append(scrollView)
      configureScrollView(scrollView, amountOfScrollView: contentView.scrollViews.count)
    }

    computeContentSize()
    setNeedsLayout()
    layoutSubviews()
  }

  /// Removes the observer for any view that gets removed from the view heirarcy.
  ///
  /// - Parameter subview: The subview that got removed from the view heirarcy.
  open override func willRemoveSubview(_ subview: UIView) {
    if let index = subviewsInLayoutOrder.index(where: { $0 == subview }) {
      subviewsInLayoutOrder.remove(at: index)
    }

    for observer in observers.filter({ $0.view === subview }) {
      if let index = observers.index(where: { $0 == observer }) {
        observers.remove(at: index)
      }
    }

    let amountOfScrollViews = contentView.scrollViews.count - 1
    for scrollView in contentView.scrollViews {
      configureScrollView(scrollView, amountOfScrollView: amountOfScrollViews)
    }

    computeContentSize()
    setNeedsLayout()
    layoutSubviews()
  }

  /// Configures all scroll view in view heirarcy if they are allowed to scroll or not.
  /// When using multiple scroll views, only horizontal collection views are allowed to
  /// scroll themselves, other views are scrolled by proxy in `layoutViews()`.
  /// All scroll views are allowed to scroll themselves if they are the only one in the
  /// view heirarcy.
  ///
  /// - Parameter scrollView: The scroll view that will be configured.
  func configureScrollView(_ scrollView: UIScrollView, amountOfScrollView: Int) {
    #if os(iOS)
      scrollView.scrollsToTop = false
      if let collectionView = scrollView as? UICollectionView,
        let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout, layout.scrollDirection == .horizontal {
        scrollView.isScrollEnabled = true
      } else {
        scrollView.isScrollEnabled = amountOfScrollView == 1
      }
    #else
      if amountOfScrollView > 1 {
        for case let scrollView as UIScrollView in subviewsInLayoutOrder {
          scrollView.isScrollEnabled = ((scrollView as? UICollectionView)?.collectionViewLayout as? UICollectionViewFlowLayout)?.scrollDirection == .horizontal
        }
      } else {
        scrollView.isScrollEnabled = true
      }
    #endif
  }

  /// Sets up observers for the view that gets added into the view heirarcy.
  /// It checks for content size, content offset and bounds changes on the view.
  /// If any of the observered values change, then layout algorithm is invoked
  /// to ensure that the views are rendered correctly in vertical linear order.
  ///
  /// - Parameter view: The view that should be observered.
  private func observeView(view: UIScrollView) {
    guard view.superview == contentView else { return }

    let contentSizeObserver = view.observe(\.contentSize, options: [.initial, .new, .old], changeHandler: { [weak self] (scrollView, value) in
      guard let strongSelf = self,
        let newValue = value.newValue,
        let oldValue = value.oldValue else {
          return
      }

      if newValue != oldValue {
        strongSelf.computeContentSize()
        strongSelf.layoutViews()
      }
    })

    let contentOffsetObserver = view.observe(\.contentOffset, options: [.new, .old], changeHandler: { [weak self] (_, value) in
      guard let newValue = value.newValue, let oldValue = value.oldValue else {
        return
      }

      if newValue.y != oldValue.y {
        self?.layoutViews()
      }
    })

    observers.append(Observer(view: view, keyValueObservation: contentSizeObserver))
    observers.append(Observer(view: view, keyValueObservation: contentOffsetObserver))
    let boundsObserver = view.observe(\.bounds, options: [.new, .old], changeHandler: { [weak self] (_, value) in
      guard let newValue = value.newValue, let oldValue = value.oldValue else {
        return
      }

      if newValue.origin.y != oldValue.origin.y {
        self?.layoutViews()
      }
    })

    observers.append(Observer(view: view, keyValueObservation: boundsObserver))
  }

  /// Computes the content size for the collection view based on
  /// combined content size of all the underlaying scroll views.
  private func computeContentSize() {
    let computedHeight = subviewsInLayoutOrder.reduce(0, { $0 + $1.contentSize.height + spacingBetweenViews })

    let minimumContentHeight = bounds.height - (contentInset.top + contentInset.bottom)
    let height = fmax(computedHeight, minimumContentHeight)

    contentSize = CGSize(width: bounds.size.width, height: height)
  }

  /// This method will call the layout algorithm without duration
  /// and computed the current content size for the scroll view.
  /// It is invoked when ever the `FamilyScrollView` needs to
  /// layout out its subviews. This methods should never be called
  /// directly, call `setNeedsLayout()` instead.
  open override func layoutSubviews() {
    super.layoutSubviews()
    layoutViews()
    computeContentSize()
  }

  /// This methods decides if the layout algoritm should be performed with
  /// animation. When a `duration` is based, the algorithm will use this
  /// `duration` and run the algorithm inside an animation block.
  /// If any of the views are animating at the time of this method being invoked,
  /// the layout algorithm will try and resolve this duration and use this as
  /// duration for the layout algorithm.
  ///
  /// - Parameter duration: Duration is used to set an animation duration
  ///                       if the layout algorithm should be performed
  ///                       with animation. It defaults to `nil` and opts
  ///                       out from animating if the view is scroll by the user.
  public func layoutViews(withDuration duration: CFTimeInterval? = nil) {
    guard superview != nil else { return }

    contentView.frame = bounds
    contentView.bounds = CGRect(origin: contentOffset, size: bounds.size)

    let animationDuration: TimeInterval? = subviewsInLayoutOrder
      .flatMap({ $0.layer.resolveAnimationDuration }).first ?? duration

    if let duration = animationDuration {
      let options: UIViewAnimationOptions = [.allowUserInteraction, .beginFromCurrentState]
      UIView.animate(withDuration: duration, delay: 0.0, options: options, animations: {
        self.runLayoutSubviewsAlgorithm()
      })
    } else {
      runLayoutSubviewsAlgorithm()
    }
  }

  /// The layout algorithm simply lays out the view in linear order vertically
  /// based on the views index inside `subviewsInLayoutOrder`. This is invoked
  /// when a view changes size or origin. It also scales the frame of scroll views
  /// in order to keep dequeuing for table and collection views.
  private func runLayoutSubviewsAlgorithm() {
    let multipleComponents = subviewsInLayoutOrder.count > 1
    var yOffsetOfCurrentSubview: CGFloat = 0.0
    for scrollView in subviewsInLayoutOrder {
      var frame = scrollView.frame
      var contentOffset = scrollView.contentOffset

      if self.contentOffset.y < yOffsetOfCurrentSubview {
        contentOffset.y = 0.0
        frame.origin.y = yOffsetOfCurrentSubview
      } else {
        contentOffset.y = self.contentOffset.y - yOffsetOfCurrentSubview
        frame.origin.y = self.contentOffset.y
      }

      let remainingBoundsHeight = fmax(bounds.maxY - yOffsetOfCurrentSubview, 0.0)
      let remainingContentHeight = fmax(scrollView.contentSize.height - contentOffset.y, 0.0)
      var newHeight: CGFloat = ceil(fmin(remainingBoundsHeight, remainingContentHeight))

      switch multipleComponents {
      case true:
        if scrollView is FamilyWrapperView {
          newHeight = fmin(contentView.frame.height, scrollView.contentSize.height)
        } else {
          newHeight = fmin(contentView.frame.height, newHeight)
        }

        let shouldModifyContentOffset = contentOffset.y <= scrollView.contentSize.height ||
          self.contentOffset.y != frame.minY

        if shouldModifyContentOffset {
          scrollView.contentOffset.y = contentOffset.y
        } else {
          frame.origin.y = yOffsetOfCurrentSubview
        }
      case false:
        newHeight = fmin(contentView.frame.height, scrollView.contentSize.height)
      }

      frame.size.height = newHeight

      if scrollView.frame != frame {
        scrollView.frame = frame
      }

      yOffsetOfCurrentSubview += scrollView.contentSize.height + spacingBetweenViews
    }
  }
}
