import UIKit

public class FamilyScrollView: UIScrollView, FamilyDocumentViewDelegate, UIGestureRecognizerDelegate {
  /// The amount of insets that should be inserted inbetween views.
  public var insets: Insets {
    get { return spaceManager.insets }
    set {
      spaceManager.insets = newValue
      cache.invalidate()
    }
  }

  /// The current viewport
  public var documentVisibleRect: CGRect {
    return CGRect(origin: contentOffset,
                  size: frame.size)
  }

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
  internal lazy var spaceManager = FamilySpaceManager()
  internal var isPerformingBatchUpdates: Bool = false
  lazy var cache = FamilyCache()
  private var isScrolling: Bool { return isTracking || isDragging || isDecelerating }

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
  public var documentView: FamilyDocumentView = FamilyDocumentView()

  deinit {
    subviewsInLayoutOrder.removeAll()
    observers.removeAll()
    spaceManager.removeAll()
  }

  /// Initializes and returns a newly allocated view object with the specified frame rectangle.
  ///
  /// - Parameter frame: The frame rectangle for the view, measured in points.
  public required override init(frame: CGRect) {
    super.init(frame: frame)
    documentView.delegate = self
    documentView.familyScrollView = self
    documentView.autoresizingMask = self.autoresizingMask
    if #available(iOS 11.0, tvOS 11.0, *) {
      contentInsetAdjustmentBehavior = .never
    }
    addSubview(documentView)
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

  func familyDocumentView(_ view: FamilyDocumentView,
                          didAddScrollView scrollView: UIScrollView) {
    didAddScrollViewToContainer(scrollView)
  }

  /// This configures observers and configures the scroll views
  /// that gets added to the view heirarcy. See `observeView` for
  /// more information about which properties that get observed.
  ///
  /// - Parameter scrollView: The scroll view that should be configured
  ///                         and observed.
  func didAddScrollViewToContainer(_ scrollView: UIScrollView) {
    scrollView.autoresizingMask = [.flexibleWidth]

    guard documentView.subviews.index(of: scrollView) != nil else {
      return
    }

    observeView(view: scrollView)

    subviewsInLayoutOrder.removeAll()
    for scrollView in documentView.scrollViews {
      subviewsInLayoutOrder.append(scrollView)
      configureScrollView(scrollView)
    }

    cache.invalidate()
    setNeedsLayout()
    layoutIfNeeded()
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

    for scrollView in documentView.scrollViews {
      configureScrollView(scrollView)
    }

    spaceManager.removeView(subview)
    cache.invalidate()
    layoutIfNeeded()
  }

  /// Configures all scroll view in view heirarcy if they are allowed to scroll or not.
  /// When using multiple scroll views, only horizontal collection views are allowed to
  /// scroll themselves, other views are scrolled by proxy in `layoutViews()`.
  /// All scroll views are allowed to scroll themselves if they are the only one in the
  /// view heirarcy.
  ///
  /// - Parameter scrollView: The scroll view that will be configured.
  func configureScrollView(_ scrollView: UIScrollView) {
    #if os(iOS)
    scrollView.scrollsToTop = false
    if let collectionView = scrollView as? UICollectionView,
      (collectionView.collectionViewLayout as? UICollectionViewFlowLayout)?.scrollDirection == .horizontal {
      scrollView.isScrollEnabled = true
    } else {
      scrollView.isScrollEnabled = false
    }
    #else
    for scrollView in subviewsInLayoutOrder {
      scrollView.isScrollEnabled = scrollViewIsHorizontal(scrollView)
    }
    #endif
  }

  /// Check if the scroll view is of horizontal nature.
  ///
  /// - Parameter scrollView: The target scroll view.
  /// - Returns: `true` if the scroll view as scroll direction set to horizontal.
  private func scrollViewIsHorizontal(_ scrollView: UIScrollView) -> Bool {
    return ((scrollView as? UICollectionView)?.collectionViewLayout as? UICollectionViewFlowLayout)?.scrollDirection == .horizontal
  }

  /// Sets up observers for the view that gets added into the view heirarcy.
  /// It checks for content size, content offset and bounds changes on the view.
  /// If any of the observered values change, then layout algorithm is invoked
  /// to ensure that the views are rendered correctly in vertical linear order.
  ///
  /// - Parameter view: The view that should be observered.
  private func observeView(view: UIScrollView) {
    guard view.superview == documentView else { return }

    for observer in observers.filter({ $0.view === view }) {
      if let index = observers.index(where: { $0 == observer }) {
        observers.remove(at: index)
      }
    }

    let contentSizeObserver = view.observe(\.contentSize, options: [.initial, .new, .old], changeHandler: { [weak self] (scrollView, value) in
      guard let strongSelf = self,
        let newValue = value.newValue,
        let oldValue = value.oldValue else {
          return
      }

      if self?.compare(newValue, to: oldValue) == false {
        let contentOffset = strongSelf.contentOffset
        strongSelf.cache.invalidate()
        strongSelf.layoutViews()
        if !strongSelf.isScrolling {
          strongSelf.setContentOffset(contentOffset, animated: false)
        }
      }
    })

    observers.append(Observer(view: view, keyValueObservation: contentSizeObserver))

    let hiddenObserver = view.observe(\.isHidden, options: [.new, .old], changeHandler: { [weak self] (_, value) in
      guard let newValue = value.newValue, let oldValue = value.oldValue else {
        return
      }

      if newValue != oldValue {
        self?.cache.invalidate()
        self?.layoutViews()
      }
    })
    observers.append(Observer(view: view, keyValueObservation: hiddenObserver))
  }

  /// Computes the content size for the collection view based on
  /// combined content size of all the underlaying scroll views.
  internal func computeContentSize() -> CGSize {
    let computedHeight = subviewsInLayoutOrder
      .filter({ $0.isHidden == false || ($0 as? FamilyWrapperView)?.view.isHidden == false })
      .reduce(CGFloat(0), { value, view in
        let insets = spaceManager.customInsets(for: (view as? FamilyWrapperView)?.view ?? view)
        return value + view.contentSize.height + insets.top + insets.bottom
      })
    let minimumContentHeight = bounds.height - (contentInset.top + contentInset.bottom)
    let height = fmax(computedHeight, minimumContentHeight)

    return CGSize(width: bounds.size.width, height: height)
  }

  /// This method will call the layout algorithm without duration
  /// and computed the current content size for the scroll view.
  /// It is invoked when ever the `FamilyScrollView` needs to
  /// layout out its subviews. This methods should never be called
  /// directly, call `setNeedsLayout()` instead.
  open override func layoutSubviews() {
    super.layoutSubviews()
    layoutViews()
  }

  public func customInsets(for view: View) -> Insets {
    return spaceManager.customInsets(for: view)
  }

  public func setCustomInsets(_ insets: Insets, for view: View) {
    spaceManager.setCustomInsets(insets, for: view)
    cache.invalidate()
    layoutViews()
  }

  /// Remove wrapper views that don't own their underlaying views.
  func purgeWrapperViews() {
    for case let wrapperView as FamilyWrapperView in documentView.subviews {
      if wrapperView != wrapperView.view.superview {
        wrapperView.removeFromSuperview()
      }
    }

    spaceManager.removeViewsWithoutSuperview()
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
  public func layoutViews(withDuration duration: CFTimeInterval? = nil,
                          completion: (() -> Void)? = nil) {
    guard isPerformingBatchUpdates == false else { return }

    guard superview != nil else { return }

    documentView.frame = bounds
    documentView.bounds = CGRect(origin: contentOffset, size: bounds.size)

    let animationDuration: TimeInterval? = subviewsInLayoutOrder
      .compactMap({ $0.layer.resolveAnimationDuration }).first ?? duration

    if let duration = animationDuration {
      let options: UIView.AnimationOptions = [.allowUserInteraction, .beginFromCurrentState]
      UIView.animate(withDuration: duration, delay: 0.0, options: options, animations: {
        self.runLayoutSubviewsAlgorithm()
      }, completion: { _ in completion?() })
    } else {
      runLayoutSubviewsAlgorithm()
      completion?()
    }
  }

  internal func compare(_ lhs: CGSize, to rhs: CGSize) -> Bool {
    return (abs(lhs.height - rhs.height) <= 0.001)
  }

  internal func compare(_ lhs: CGPoint, to rhs: CGPoint) -> Bool {
    return (abs(lhs.y - rhs.y) <= 0.001)
  }
}
