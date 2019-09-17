import UIKit

public class FamilyScrollView: UIScrollView, UIGestureRecognizerDelegate {
  private var previousContentOffset: CGPoint?

  var scrollViews: [UIScrollView] {
    return subviews.compactMap { $0 as? UIScrollView }
  }

  var isFastScrolling: Bool = false

  /// The amount of insets that should be inserted inbetween views.
  public var margins: Insets {
    get { return spaceManager.defaultMargins }
    set {
      spaceManager.defaultMargins = newValue
      invalidateLayout()
    }
  }

  public var padding: Insets {
    get { return spaceManager.defaultPadding }
    set {
      spaceManager.defaultPadding = newValue
      invalidateLayout()
    }
  }

  internal var backgrounds = [UIView: UIView]()

  public override var bounds: CGRect {
    willSet {
      if newValue.width != bounds.width {
        invalidateLayout()
      }
    }
  }

  internal var isDeallocating: Bool = false
  internal var isChildViewController: Bool = false

  internal var validRect: CGRect {
    var rect = documentVisibleRect
    let offset = bounds.size.height * 2
    rect.origin.y = max(self.contentOffset.y - (offset / 2), 0)
    rect.size.height = bounds.size.height + offset
    return rect
  }

  internal var discardableRect: CGRect {
    var rect = documentVisibleRect
    let offset = bounds.size.height * 2.5
    rect.origin.y = max(self.contentOffset.y - (offset / 2), 0)
    rect.size.height = bounds.size.height + offset
    return rect
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
  var isScrolling: Bool { return isTracking || isDragging || isDecelerating }

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

  override public var frame: CGRect {
    willSet {
      if newValue.width != frame.width {
        invalidateLayout()
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
    clipsToBounds = true
    autoresizesSubviews = false
    if #available(iOS 11.0, tvOS 11.0, *) {
      contentInsetAdjustmentBehavior = .never
    }
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

  /// Adds a view to the end of the receiver’s list of subviews.
  /// If view do not inherit from `UIScrollView`, the view will be
  /// wrapped in a `FamilyWrapperView` that works as a scroll view
  /// for the view.
  ///
  /// - Parameter view: The view to be added.
  ///                   After being added, this view appears on top of any other subviews.
  open override func addSubview(_ view: UIView) {
    if backgrounds.values.contains(view) {
      super.addSubview(view)
      return
    }

    if view.description.contains("_UIFocusFastScrollingIndexBarView") {
      isFastScrolling = true
      super.addSubview(view)
      return
    }

    let subview = wrapViewIfNeeded(view)
    super.addSubview(subview)
    guard let scrollView = subview as? UIScrollView else { return }
    didAddScrollViewToContainer(scrollView)
    purgeViews()
  }

  public override func insertSubview(_ view: UIView, at index: Int) {
    if backgrounds.values.contains(view) {
      super.addSubview(view)
      return
    }
    let subview = wrapViewIfNeeded(view)
    super.insertSubview(subview, at: index)
    guard let scrollView = subview as? UIScrollView else { return }
    didAddScrollViewToContainer(scrollView)
    purgeViews()
  }

  private func wrapViewIfNeeded(_ view: UIView) -> UIView {
    let subview: UIView

    switch view {
    case let scrollView as UIScrollView:
      subview = scrollView
    default:
      let wrapper = FamilyWrapperView(frame: view.frame,
                                      view: view)
      wrapper.familyScrollView = self
      subview = wrapper
    }

    return subview
  }

  private func purgeViews() {
    for case let wrapperView as FamilyWrapperView in subviews {
      if wrapperView.view.superview != wrapperView {
        wrapperView.removeFromSuperview()
      }
    }
  }

  func addBackground(_ backgroundView: UIView, to view: UIView) {
    if backgrounds[view] != nil {
      backgrounds[view]?.removeFromSuperview()
    }
    backgrounds[view] = backgroundView
    addSubview(backgroundView)
    sendSubviewToBack(backgroundView)
    invalidateLayout()
    guard !isPerformingBatchUpdates else { return }
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

    guard subviews.firstIndex(of: scrollView) != nil else {
      return
    }

    observeView(view: scrollView)

    subviewsInLayoutOrder.removeAll()
    for scrollView in scrollViews {
      subviewsInLayoutOrder.append(scrollView)
      configureScrollView(scrollView)
    }

    invalidateLayout()
    setNeedsLayout()
    layoutIfNeeded()
  }

  /// Removes the observer for any view that gets removed from the view heirarcy.
  ///
  /// - Parameter subview: The subview that got removed from the view heirarcy.
  open override func willRemoveSubview(_ subview: UIView) {
    if subview.description.contains("_UIFocusFastScrollingIndexBarView") {
      isFastScrolling = false
      return
    }

    if let index = subviewsInLayoutOrder.firstIndex(where: { $0 == subview }) {
      subviewsInLayoutOrder.remove(at: index)
    }

    for observer in observers.filter({ $0.view === subview }) {
      if let index = observers.firstIndex(where: { $0 == observer }) {
        observers.remove(at: index)
      }
    }

    for scrollView in scrollViews {
      configureScrollView(scrollView)
    }

    if let wrapperView = subview as? FamilyWrapperView,
      let backgroundView = backgrounds[wrapperView.view] {
      backgroundView.removeFromSuperview()
    } else if let backgroundView = backgrounds[subview] {
      backgroundView.removeFromSuperview()
    }

    spaceManager.removeView(subview)
    invalidateLayout()
    guard !isPerformingBatchUpdates else { return }
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
    guard view.superview == self else { return }

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
        strongSelf.invalidateLayout()
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
        self?.invalidateLayout()
        self?.layoutViews(animation: animation)
      }
    })
    observers.append(Observer(view: view, keyValueObservation: hiddenObserver))

    let contentOffsetObserver = view.observe(\.contentOffset, options: [.new], changeHandler: { [weak self] (scrollView, value) in
      guard let strongSelf = self,
        let newValue = value.newValue,
        value.oldValue != nil else {
        return
      }

      if strongSelf.scrollViewIsHorizontal(scrollView), abs(newValue.y) != 0 {
        scrollView.contentOffset.y = 0
        strongSelf.layoutViews()
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
    guard insets != spaceManager.padding(for: view) else { return }
    spaceManager.addPadding(insets, for: view)
    invalidateLayout()
    guard !isPerformingBatchUpdates else { return }
    layoutViews()
  }

  public func margins(for view: View) -> Insets {
    return spaceManager.margins(for: view)
  }

  public func addMargins(_ insets: Insets, for view: View) {
    guard insets != spaceManager.margins(for: view) else { return }
    spaceManager.addMargins(insets, for: view)
    invalidateLayout()
    guard !isPerformingBatchUpdates else { return }
    layoutViews()
  }

  func invalidateLayout() {
    cache.invalidate()
    self.previousContentOffset = nil
  }

  /// Remove wrapper views that don't own their underlaying views.
  func purgeWrapperViews() {
    for case let wrapperView as FamilyWrapperView in subviews {
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
    guard !isPerformingBatchUpdates else { return }
    guard !isDeallocating else { return }
    guard superview != nil else {
      completion?()
      return
    }

    // Skip extra rendering pass.
    #if os(tvOS)
    if let previousContentOffset = previousContentOffset, duration == nil {
      if previousContentOffset == contentOffset {
        return
      }
    }
    #endif

    if !isScrolling {
      purgeOffscreenViews(using: contentOffset)
    }

    // Make sure that wrapper views have the correct width
    // on their wrapped views.
    if cache.state == .empty { adjustViewsWithPaddingAndMargins() }

    let options: UIView.AnimationOptions = [.allowUserInteraction, .beginFromCurrentState, .preferredFramesPerSecond60]
    let animations = { self.runLayoutSubviewsAlgorithm() }
    let animationCompletion: (Bool) -> Void = { _ in
      completion?()
      self.previousContentOffset = nil
    }

    if #available(iOS 9.0, *) {
      if let animation = animation {
        switch animation {
        case let springAnimation as CASpringAnimation:
          UIView.animate(withDuration: springAnimation.duration, delay: 0.0,
                         usingSpringWithDamping: springAnimation.damping,
                         initialSpringVelocity: springAnimation.initialVelocity,
                         options: options, animations: animations, completion: animationCompletion)
        default:
          UIView.animate(withDuration: animation.duration, delay: 0.0, options: options, animations: runLayoutSubviewsAlgorithm, completion: animationCompletion)
        }
        return
      }
    }

    if let duration = duration, duration > 0.0 {
      self.previousContentOffset = self.contentOffset
      UIView.animate(withDuration: duration, delay: 0.0,
                     options: options,
                     animations: runLayoutSubviewsAlgorithm,
                     completion: animationCompletion)
    } else {
      runLayoutSubviewsAlgorithm()
      self.previousContentOffset = self.contentOffset
    }
  }

  private func purgeOffscreenViews(using contentOffset: CGPoint) {
    var rect = documentVisibleRect
    let offset = bounds.size.height * 2.5
    rect.origin.y = max(contentOffset.y - (offset / 2), 0)
    rect.size.height = bounds.size.height + offset
    // Clean up invalid views.
    let discardableScrollViews = subviewsInLayoutOrder
      .filter { $0.frame.size.height != 0 && !$0.frame.intersects(discardableRect) }
    for scrollView in discardableScrollViews {
      scrollView.frame.size.height = 0
    }
  }

  private func adjustViewsWithPaddingAndMargins() {
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
  }

  func getValidAttributes(in rect: CGRect) -> [FamilyViewControllerAttributes] {
    let binarySearch = BinarySearch()
    let upper: (FamilyViewControllerAttributes) -> Bool = { attributes in
      let frame = attributes.scrollView.layer.presentation()?.frame ?? attributes.scrollView.frame
      return attributes.frame.maxY >= rect.minY ||
        frame.maxY >= rect.minY
    }
    let lower: (FamilyViewControllerAttributes) -> Bool = { attributes in
      let frame = attributes.scrollView.layer.presentation()?.frame ?? attributes.scrollView.frame
      return attributes.frame.minY <= rect.maxY ||
        frame.minY <= rect.maxY
    }
    let less: (FamilyViewControllerAttributes) -> Bool =  { attributes in
      let frame = attributes.scrollView.layer.presentation()?.frame ?? attributes.scrollView.frame
      return attributes.frame.maxY < rect.minY ||
        frame.maxY < rect.minY
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
    invalidateLayout()
    layoutViews()
  }

  // MARK: - Layout Algorithm

  /// The layout algorithm simply lays out the view in linear order vertically
  /// based on the views index inside `subviewsInLayoutOrder`. This is invoked
  /// when a view changes size or origin. It also scales the frame of scroll views
  /// in order to keep dequeuing for table and collection views.
  internal func runLayoutSubviewsAlgorithm() {
    guard cache.state != .isRunning else { return }

    let parentContentOffset = CGPoint(x: self.contentOffset.x,
                                      y: self.contentOffset.y)

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

        if parentContentOffset.y < yOffsetOfCurrentSubview {
          contentOffset.y = 0.0
          frame.origin.y = round(yOffsetOfCurrentSubview)
        } else {
          contentOffset.y = round(parentContentOffset.y - yOffsetOfCurrentSubview)
          frame.origin.y = parentContentOffset.y
        }

        let remainingBoundsHeight = fmax(bounds.maxY - yOffsetOfCurrentSubview, 0.0)
        let remainingContentHeight = fmax(scrollView.contentSize.height - contentOffset.y, 0.0)
        var newHeight: CGFloat = ceil(fmin(remainingBoundsHeight, remainingContentHeight))

        if scrollView is FamilyWrapperView {
          newHeight = fmin(self.frame.height, scrollView.contentSize.height)
          frame.origin.x = margins.left
        } else {
          newHeight = fmin(self.frame.height, newHeight)
          frame.origin.x = padding.left
        }

        frame.size.width = self.frame.size.width - margins.left - margins.right
        frame.size.height = round(newHeight)
        frame.origin.y = round(yOffsetOfCurrentSubview)

        if !frame.intersects(documentVisibleRect) {
          frame.size.height = 0
        }

        if let attributes = FamilyViewControllerAttributes(view: view,
                                                           origin: CGPoint(x: frame.origin.x,
                                                                           y: round(yOffsetOfCurrentSubview + padding.top)),
                                                           contentSize: scrollView.contentSize) {
          cache.add(entry: attributes)
        } else {
          yOffsetOfCurrentSubview -= margins.top
          continue
        }

        scrollView.frame = frame

        if let backgroundView = backgrounds[view] {
          frame.origin.y = round(yOffsetOfCurrentSubview)
          positionBackgroundView(scrollView, frame, margins, padding, backgroundView, view)
        }

        if scrollView.contentSize.height > 0 {
          yOffsetOfCurrentSubview += round(scrollView.contentSize.height + margins.bottom + padding.top + padding.bottom)
        }
      }

      let computedHeight = round(yOffsetOfCurrentSubview)
      let minimumContentHeight = bounds.height - (contentInset.top + contentInset.bottom)
      var height = fmax(computedHeight, minimumContentHeight)
      cache.contentSize = CGSize(width: bounds.size.width, height: computedHeight)

      if isChildViewController {
        height = computedHeight
        superview?.frame.size.height = cache.contentSize.height
      }

      cache.state = .isFinished
      contentSize = CGSize(width: cache.contentSize.width, height: round(height))
    }

    let validAttributes = getValidAttributes(in: discardableRect)
    for attributes in validAttributes where attributes.view.isHidden == false  {
      let scrollView = attributes.scrollView
      let padding = spaceManager.padding(for: attributes)
      var frame = scrollView.frame
      var contentOffset = scrollView.contentOffset

      if parentContentOffset.y < attributes.frame.origin.y {
        contentOffset.y = 0.0
        frame.origin.y = round(scrollView.frame.origin.y)
      } else {
        contentOffset.y = round(parentContentOffset.y - attributes.frame.origin.y)
        frame.origin.y = round(parentContentOffset.y)
      }

      var newHeight: CGFloat = fmin(self.frame.height, scrollView.contentSize.height)

      if !attributes.frame.intersects(validRect) {
        newHeight = 0
      }

      // Only add padding if the new height exceeds zero.
      if newHeight > 0 {
        newHeight += padding.top + padding.bottom
      }

      let shouldScroll = attributes.frame.intersects(documentVisibleRect) &&
        round(attributes.contentSize.height) > round(self.frame.size.height)

      if scrollView is FamilyWrapperView {
        if scrollView.contentOffset.y != contentOffset.y && parentContentOffset.y < scrollView.frame.origin.y {
          scrollView.contentOffset.y = contentOffset.y
        } else {
          frame.origin.y = attributes.frame.origin.y
        }
      } else if shouldScroll {
        scrollView.contentOffset.y = contentOffset.y
        if round(self.contentOffset.y) < frame.origin.y && frame.origin.y != attributes.frame.origin.y {
          frame.origin.y = attributes.frame.origin.y
        }
      } else {
        frame.origin.y = attributes.origin.y
        // Reset content offset to avoid setting offsets that
        // look liked `clipsToBounds` bugs.
        if self.contentOffset.y < attributes.maxY {
          scrollView.contentOffset.y = 0
        }
      }

      frame.size.height = round(newHeight)

      if scrollView.frame != frame {
        scrollView.frame = frame
      }
    }
  }
}
