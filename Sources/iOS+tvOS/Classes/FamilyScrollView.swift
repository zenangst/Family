import UIKit

public class FamilyScrollView: UIScrollView, FamilyDocumentViewDelegate, UIGestureRecognizerDelegate {
  /// The amount of insets that should be inserted inbetween views.
  public var margins: Insets {
    get { return spaceManager.defaultMargins }
    set {
      spaceManager.defaultMargins = newValue
      cache.invalidate()
    }
  }

  public var padding: Insets {
    get { return spaceManager.defaultPadding }
    set {
      spaceManager.defaultPadding = newValue
      cache.invalidate()
    }
  }

  internal var backgrounds = [UIView: UIView]()

  public override var bounds: CGRect {
    willSet {
      if newValue.width != bounds.width {
        cache.invalidate()
      }
    }
  }

  internal var isDeallocating: Bool = false
  internal var isChildViewController: Bool = false

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
  public lazy var documentView: FamilyDocumentView = FamilyDocumentView()

  override public var frame: CGRect {
    willSet {
      if newValue.width != frame.width {
        cache.invalidate()
      }
    }
  }

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
    autoresizesSubviews = false
    documentView.backgroundColor = .clear
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

  public override func setNeedsLayout() {
    guard !isDeallocating else { return }
    super.setNeedsLayout()
  }

  public override func layoutIfNeeded() {
    guard !isDeallocating else { return }
    super.layoutIfNeeded()
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

  func addBackground(_ backgroundView: UIView, to view: UIView) {
    if backgrounds[view] != nil {
      backgrounds[view]?.removeFromSuperview()
    }
    backgrounds[view] = backgroundView
    addSubview(backgroundView)
    sendSubviewToBack(backgroundView)
    cache.invalidate()
    layoutViews()
  }

  /// This configures observers and configures the scroll views
  /// that gets added to the view heirarcy. See `observeView` for
  /// more information about which properties that get observed.
  ///
  /// - Parameter scrollView: The scroll view that should be configured
  ///                         and observed.
  func didAddScrollViewToContainer(_ scrollView: UIScrollView) {
    scrollView.autoresizingMask = [.flexibleWidth]

    guard documentView.subviews.firstIndex(of: scrollView) != nil else {
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
    if let index = subviewsInLayoutOrder.firstIndex(where: { $0 == subview }) {
      subviewsInLayoutOrder.remove(at: index)
    }

    for observer in observers.filter({ $0.view === subview }) {
      if let index = observers.firstIndex(where: { $0 == observer }) {
        observers.remove(at: index)
      }
    }

    for scrollView in documentView.scrollViews {
      configureScrollView(scrollView)
    }

    if let wrapperView = subview as? FamilyWrapperView,
      let backgroundView = backgrounds[wrapperView.view] {
      backgroundView.removeFromSuperview()
    } else if let backgroundView = backgrounds[subview] {
      backgroundView.removeFromSuperview()
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
      if let index = observers.firstIndex(where: { $0 == observer }) {
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
        let targetView = (scrollView as? FamilyWrapperView)?.view ?? scrollView
        let animation = targetView.layer.allAnimationsWithKeys.first
        strongSelf.layoutViews(animation: animation)
        if !strongSelf.isScrolling {
          strongSelf.setContentOffset(contentOffset, animated: false)
        }
      }
    })
    observers.append(Observer(view: view, keyValueObservation: contentSizeObserver))

    let hiddenObserver = view.observe(\.isHidden, options: [.new, .old], changeHandler: { [weak self] (scrollView, value) in
      guard let newValue = value.newValue, let oldValue = value.oldValue else {
        return
      }

      if newValue != oldValue {
        let targetView = (scrollView as? FamilyWrapperView)?.view ?? scrollView
        let animation = targetView.layer.allAnimationsWithKeys.first
        self?.cache.invalidate()
        self?.layoutViews(animation: animation)
      }
    })
    observers.append(Observer(view: view, keyValueObservation: hiddenObserver))

    let contentOffsetObserver = view.observe(\.contentOffset, options: [.new], changeHandler: { [weak self] (scrollView, value) in
      guard let strongSelf = self, let newValue = value.newValue else {
        return
      }

      if strongSelf.scrollViewIsHorizontal(scrollView), abs(newValue.y) != 0 {
        scrollView.contentOffset.y = 0
        strongSelf.runLayoutSubviewsAlgorithm()
      }
    })
    observers.append(Observer(view: view, keyValueObservation: contentOffsetObserver))
  }

  func positionBackgroundView(_ scrollView: UIScrollView, _ frame: CGRect, _ margins: Insets, _ padding: Insets, _ backgroundView: UIView, _ view: UIView) {
    if scrollView.contentSize.height > 0 {
      var backgroundFrame = frame
      backgroundFrame.origin.x = margins.left
      backgroundFrame.origin.y = frame.origin.y
      backgroundFrame.size.height = scrollView.contentSize.height + padding.top + padding.bottom
      backgroundFrame.size.width = self.frame.size.width - margins.left - margins.right

      UIView.performWithoutAnimation {
        backgroundView.frame = backgroundFrame
        backgroundView.isHidden = false
      }
    } else {
      backgrounds[view]?.isHidden = true
    }
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

  public func padding(for view: View) -> Insets {
    return spaceManager.padding(for: view)
  }

  public func addPadding(_ insets: Insets, for view: View) {
    spaceManager.addPadding(insets, for: view)
    cache.invalidate()
    layoutViews()
  }

  public func margins(for view: View) -> Insets {
    return spaceManager.margins(for: view)
  }

  public func addMargins(_ insets: Insets, for view: View) {
    spaceManager.addMargins(insets, for: view)
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
  public func layoutViews(withDuration duration: Double? = nil,
                          animation: CAAnimation? = nil,
                          completion: (() -> Void)? = nil) {
    guard isPerformingBatchUpdates == false else { return }

    guard !isDeallocating else { return }

    guard superview != nil else {
      completion?()
      return
    }

    // Make sure that wrapper views have the correct width
    // on their wrapped views.
    for case let scrollView in subviewsInLayoutOrder {
      let wrapperView = scrollView as? FamilyWrapperView
      let padding = spaceManager.padding(for: wrapperView?.view ?? scrollView)
      let margins = spaceManager.margins(for: wrapperView?.view ?? scrollView)

      if let wrapperView = wrapperView {
        let expectedWidth = frame.size.width - margins.left - margins.right
        let expectedWrappedWidth = frame.size.width - margins.left - margins.right - padding.left - padding.right

        if scrollView.frame.origin.x != margins.left {
          scrollView.frame.origin.x = margins.left
        }

        if scrollView.frame.size.width != expectedWidth {
          scrollView.frame.size.width = expectedWidth
        }

        if wrapperView.view.frame.origin.x != padding.left {
          wrapperView.view.frame.origin.x = padding.left
        }

        if wrapperView.view.frame.origin.y != padding.top {
          wrapperView.view.frame.origin.y = padding.top
        }

        if wrapperView.view.frame.size.width != expectedWrappedWidth {
          wrapperView.view.frame.size.width = expectedWrappedWidth
        }
      } else {
        let expectedWidth = frame.size.width - padding.left - padding.right - margins.left - margins.right

        if scrollView.frame.origin.x != margins.left {
          scrollView.frame.origin.x = margins.left + padding.left
        }

        if scrollView.frame.size.width != expectedWidth {
          scrollView.frame.size.width = expectedWidth
        }
      }
    }

    if documentView.frame != bounds {
      documentView.frame = bounds
      documentView.bounds = CGRect(origin: contentOffset, size: bounds.size)
    }

    let options: UIView.AnimationOptions = [.allowUserInteraction, .beginFromCurrentState]
    let animations = { self.runLayoutSubviewsAlgorithm() }
    let animationCompletion: (Bool) -> Void = { _ in completion?() }

    if #available(iOS 9.0, *) {
      if let animation = animation {
        switch animation {
        case let springAnimation as CASpringAnimation:
          UIView.animate(withDuration: springAnimation.duration, delay: 0.0,
                         usingSpringWithDamping: springAnimation.damping,
                         initialSpringVelocity: springAnimation.initialVelocity,
                         options: options, animations: animations, completion: animationCompletion)
        default:
          UIView.animate(withDuration: animation.duration, delay: 0.0, options: options, animations: {
            self.runLayoutSubviewsAlgorithm()
          }, completion: animationCompletion)
        }
        return
      }
    }

    if let duration = duration, duration > 0.0 {
      UIView.animate(withDuration: duration, delay: 0.0, options: options, animations: {
        self.runLayoutSubviewsAlgorithm()
      }, completion: animationCompletion)
    } else {
      runLayoutSubviewsAlgorithm()
      completion?()
    }
  }

  func getValidAttributes(in rect: CGRect) -> [FamilyViewControllerAttributes] {
    let binarySearch = BinarySearch()
    let upper: (FamilyViewControllerAttributes) -> Bool = { attributes in
      attributes.frame.maxY >= rect.minY ||
      attributes.scrollView.frame.maxY >= rect.minY
    }
    let lower: (FamilyViewControllerAttributes) -> Bool = { attributes in
      attributes.frame.minY <= rect.maxY ||
      attributes.scrollView.frame.minY <= rect.maxY
    }
    let less: (FamilyViewControllerAttributes) -> Bool =  { attributes in
      attributes.frame.maxY < rect.minY ||
      attributes.scrollView.frame.maxY < rect.minY
    }
    let attributes = cache.collection
    let validAttributes = binarySearch.findElements(in: attributes,
                                                    upper: upper,
                                                    lower: lower,
                                                    less: less,
                                                    match: { $0.frame.intersects(rect) })
    return validAttributes
  }

  internal func compare(_ lhs: CGSize, to rhs: CGSize) -> Bool {
    return (abs(lhs.height - rhs.height) <= 0.001)
  }

  internal func compare(_ lhs: CGPoint, to rhs: CGPoint) -> Bool {
    return (abs(lhs.y - rhs.y) <= 0.001)
  }

  @objc func injected() {
    cache.invalidate()
    layoutViews()
  }
}
