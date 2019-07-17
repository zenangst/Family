import Cocoa

public class FamilyScrollView: NSScrollView {
  public override var isFlipped: Bool { return true }
  public lazy var familyDocumentView: FamilyDocumentView = .init()
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

  internal var backgrounds = [NSView: NSView]()

  @objc(scrollEnabled)
  public var isScrollEnabled: Bool = true
  internal var isDeallocating: Bool = false
  internal var isChildViewController: Bool = false

  var layoutIsRunning: Bool = false
  var isScrollingWithWheel: Bool = false
  var isScrolling: Bool = false
  var isScrollingByProxy: Bool = false
  internal var isPerformingBatchUpdates: Bool = false
  private var subviewsInLayoutOrder = [NSScrollView]()
  internal lazy var spaceManager = FamilySpaceManager()
  lazy var cache = FamilyCache()

  override public var frame: CGRect {
    willSet {
      if newValue.width != frame.width {
        cache.invalidate()
      }
    }
  }

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    self.documentView = familyDocumentView
    self.drawsBackground = false
    self.familyDocumentView.familyScrollView = self
    self.configureObservers()
    self.hasVerticalScroller = true
    self.contentView.postsBoundsChangedNotifications = true
    self.familyDocumentView.autoresizingMask = [.width]
  }

  required public init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
    familyDocumentView.subviews.forEach { $0.removeFromSuperview() }
    subviewsInLayoutOrder.forEach { $0.removeFromSuperview() }
    subviewsInLayoutOrder.removeAll()
  }

  // MARK: - Public methods

  public func layoutViews(withDuration duration: CFTimeInterval?,
                          allowsImplicitAnimation: Bool = true,
                          force: Bool,
                          completion: (() -> Void)?) {
    guard isPerformingBatchUpdates == false, !isDeallocating else { return }

    guard !layoutIsRunning || !force else {
      return
    }

    if let duration = duration, duration > 0 {
      layoutIsRunning = true
      NSAnimationContext.runAnimationGroup({ (context) in
        context.duration = duration
        context.allowsImplicitAnimation = allowsImplicitAnimation
        runLayoutSubviewsAlgorithm()
      }, completionHandler: { [weak self] in
        completion?()
        self?.layoutIsRunning = false
      })
      return
    } else if isScrolling || duration == nil {
      NSAnimationContext.beginGrouping()
      NSAnimationContext.current.duration = 0.0
      NSAnimationContext.current.allowsImplicitAnimation = false
      layoutIsRunning = true
      runLayoutSubviewsAlgorithm()
      layoutIsRunning = false
      completion?()
      NSAnimationContext.endGrouping()
      return
    }

    layoutIsRunning = true
    runLayoutSubviewsAlgorithm()
    layoutIsRunning = false
    completion?()
  }

  // MARK: - Observers

  private func configureObservers() {
    NotificationCenter.default.addObserver(
      self, selector: #selector(contentViewBoundsDidChange(_:)),
      name: NSView.boundsDidChangeNotification, object: contentView
    )

    NotificationCenter.default.addObserver(
      self,selector: #selector(windowDidResize(_:)),
      name: NSWindow.didResizeNotification, object: nil
    )

    NotificationCenter.default.addObserver(
      self, selector: #selector(windowDidResize(_:)),
      name: NSSplitView.didResizeSubviewsNotification, object: nil
    )

    NotificationCenter.default.addObserver(
      self, selector: #selector(windowDidResize(_:)),
      name: NSSplitView.willResizeSubviewsNotification, object: nil
    )

    NotificationCenter.default.addObserver(
      self, selector: #selector(windowDidEndLiveResize(_:)),
      name: NSWindow.didEndLiveResizeNotification, object: nil
    )

    NotificationCenter.default.addObserver(
      self, selector: #selector(didLiveScroll),
      name: NSScrollView.didLiveScrollNotification, object: nil
    )

    NotificationCenter.default.addObserver(
      self, selector: #selector(didEndLiveScroll),
      name: NSScrollView.didEndLiveScrollNotification, object: nil
    )
  }

  @objc func didLiveScroll() { isScrolling = true }
  @objc func didEndLiveScroll() { isScrolling = false; isScrollingWithWheel = false }

  @objc func contentViewBoundsDidChange(_ notification: NSNotification) {
    if (notification.object as? NSClipView) === contentView,
      let window = window,
      !window.inLiveResize,
      !isScrollingWithWheel {
      layoutViews(withDuration: 0.0, force: false, completion: nil)
    }
  }

  func scrollTo(_ point: CGPoint, in view: NSView) {
    let shouldScrollByProxy = isScrollingByProxy &&
      !isScrolling &&
      !layoutIsRunning &&
      view.window?.isVisible == true
    defer { isScrollingByProxy = false }
    guard shouldScrollByProxy, let entry = cache.entry(for: view) else {
      return
    }
    var newOffset = CGPoint(x: self.contentOffset.x,
                            y: entry.origin.y + point.y)
    if newOffset.y < contentOffset.y {
      newOffset.y -= contentView.contentInsets.top
    }

    if point.y == 0 {
      newOffset.y = 0
    }

    contentView.scroll(newOffset)
    // This is invoked to avoid animation stutter.
    contentView.scroll(to: newOffset)
  }

  // MARK: - Window resizing

  private func processNewWindowSize() {
    guard window != nil else { return }
    cache.invalidate()
    layoutViews(withDuration: nil, force: false, completion: nil)
  }

  @objc open func windowDidResize(_ notification: Notification) {
    processNewWindowSize()
  }

  @objc public func windowDidEndLiveResize(_ notification: Notification) {
    processNewWindowSize()
  }

  public override func viewWillMove(toSuperview newSuperview: NSView?) {
    super.viewWillMove(toSuperview: newSuperview)

    if let newSuperview = newSuperview {
      frame.size = newSuperview.frame.size
      documentView?.frame.size = .zero
    }
  }

  func addBackground(_ backgroundView: NSView, to view: NSView) {
    if backgrounds[view] != nil {
      backgrounds[view]?.removeFromSuperview()
    }
    backgrounds[view] = backgroundView
    familyDocumentView.addSubview(backgroundView, positioned: .below, relativeTo: view)
    cache.invalidate()
    layoutViews(withDuration: nil, force: false, completion: nil)
  }

  func didAddScrollViewToContainer(_ scrollView: NSScrollView) {
    if familyDocumentView.scrollViews.firstIndex(of: scrollView) != nil {
      rebuildSubviewsInLayoutOrder()
      subviewsInLayoutOrder.removeAll()

      for scrollView in familyDocumentView.scrollViews {
        subviewsInLayoutOrder.append(scrollView)
      }
    }

    cache.invalidate()
    layoutViews(withDuration: 0.0, force: false, completion: nil)
  }

  func didRemoveScrollViewToContainer(_ subview: NSView) {
    backgrounds[subview]?.removeFromSuperview()
    cache.invalidate()
  }

  public func padding(for view: View) -> Insets {
    return spaceManager.padding(for: view)
  }

  public func addPadding(_ insets: Insets, for view: View) {
    spaceManager.addPadding(insets, for: view)
    cache.invalidate()
    layoutViews(withDuration: nil, force: false, completion: nil)
  }

  public func margins(for view: View) -> Insets {
    return spaceManager.margins(for: view)
  }

  public func addMargins(_ insets: Insets, for view: View) {
    spaceManager.addMargins(insets, for: view)
    cache.invalidate()
    layoutViews(withDuration: nil, force: false, completion: nil)
  }

  /// Remove wrapper views that don't own their underlaying views.
  func purgeWrapperViews() {
    for case let wrapperView as FamilyWrapperView in familyDocumentView.subviews {
      if wrapperView != wrapperView.view.enclosingScrollView {
        wrapperView.removeFromSuperview()
      }
    }

    spaceManager.removeViewsWithoutSuperview()
  }

  public override func scrollWheel(with event: NSEvent) {
    guard isScrollEnabled else {
      nextResponder?.scrollWheel(with: event)
      return
    }
    super.scrollWheel(with: event)

    isScrolling = !(event.deltaX == 0 && event.deltaY == 0) ||
      !(event.phase == .ended || event.momentumPhase == .ended)
    isScrollingWithWheel = isScrolling

    layoutViews(withDuration: 0.0, force: false, completion: nil)
  }

  func wrapperViewDidChangeFrame(_ view: NSView, from fromValue: CGRect, to toValue: CGRect) {
    guard window != nil else { return }
    guard round(fromValue.height) != round(toValue.height) else { return }
    cache.invalidate()
    layoutViews(withDuration: nil,
                allowsImplicitAnimation: false,
                force: true,
                completion: nil)
  }

  // MARK: - Private methods

  private func rebuildSubviewsInLayoutOrder(exceptSubview: View? = nil) {
    subviewsInLayoutOrder.removeAll()
    subviewsInLayoutOrder = familyDocumentView.subviewsInLayoutOrder.filter({ !($0 === exceptSubview) })
  }

  private func validateScrollView(_ scrollView: NSScrollView) -> Bool {
    guard scrollView.documentView != nil else { return false }

    // Exlucde empty collection views.
    if let collectionView = scrollView.documentView as? NSCollectionView,
      collectionView.dataSource?.collectionView(collectionView, numberOfItemsInSection: 0) == 0 {
      return false
    }

    return scrollView.documentView?.isHidden == false && (scrollView.documentView?.alphaValue ?? 1.0) > CGFloat(0.0)
  }

  fileprivate func positionBackgroundView(_ frame: NSRect, _ backgroundView: NSView) {
    if frame.height > 0 {
      backgroundView.frame = frame
      backgroundView.isHidden = false
    } else {
      backgroundView.isHidden = true
    }
  }

  private func runLayoutSubviewsAlgorithm() {
    guard isPerformingBatchUpdates == false,
      !isDeallocating,
      cache.state != .isRunning else { return }

    var scrollViewContentOffset = self.contentOffset
    var yOffsetOfCurrentSubview: CGFloat = 0.0

    for scrollView in subviewsInLayoutOrder where validateScrollView(scrollView) {
      guard let view = scrollView.documentView else { continue }
      let contentSize: CGSize = contentSizeForView(view)
      let padding = spaceManager.padding(for: view)
      let margins = spaceManager.margins(for: view)
      let constrainedWidth = round(self.frame.size.width) - margins.left - margins.right - padding.left - padding.right

      var frame = scrollView.frame
      var viewFrame = frame
      var contentOffset = scrollView.contentOffset
      let currentXOffset = scrollView.isHorizontal ? scrollView.contentOffset.x : 0

      yOffsetOfCurrentSubview += margins.top

      let entry: FamilyViewControllerAttributes
      if let cache = cache.entry(for: view) {
        entry = cache
      } else {
        frame.origin.y = yOffsetOfCurrentSubview
        frame.origin.x = margins.left
        frame.size.height = min(visibleRect.height, contentSize.height)
        frame.size.width = round(self.frame.size.width) - margins.left - margins.right

        viewFrame.origin.x = padding.left
        viewFrame.origin.y = padding.top
        viewFrame.size.width = scrollView.isHorizontal ? contentSize.width : constrainedWidth
        viewFrame.size.height = contentSize.height
        view.frame = viewFrame

        entry = FamilyViewControllerAttributes(view: view,
                                               origin: CGPoint(x: frame.origin.x,
                                                               y: yOffsetOfCurrentSubview),
                                               contentSize: contentSize)

        cache.add(entry: entry)

        if let backgroundView = backgrounds[view] {
          let backgroundFrame = CGRect(origin: CGPoint(x: margins.left, y: yOffsetOfCurrentSubview),
                                       size: CGSize(width: round(self.frame.size.width) - margins.left - margins.right,
                                                    height: contentSize.height + padding.top + padding.bottom))
          positionBackgroundView(backgroundFrame, backgroundView)
        }

        if contentSize.height > 0 {
          yOffsetOfCurrentSubview += contentSize.height + margins.bottom + padding.top + padding.bottom
        }

        cache.state = .isRunning
      }

      // Constrain the computed offset to be inside of document visible rect.
      scrollViewContentOffset.y = min(documentVisibleRect.origin.y + contentInsets.top,
                                      cache.contentSize.height - documentVisibleRect.size.height + contentInsets.top)

      if self.contentOffset.y < entry.origin.y {
        contentOffset.y = 0
        frame.origin.y = abs(entry.origin.y)
      } else {
        contentOffset.y = abs(scrollViewContentOffset.y - entry.origin.y)
        frame.origin.y = abs(scrollViewContentOffset.y)
      }

      let remainingBoundsHeight = abs(fmax(documentVisibleRect.maxY - frame.minY, 0.0))
      let remainingContentHeight = abs(fmax(entry.contentSize.height - contentOffset.y, 0.0))
      var newHeight: CGFloat = abs(fmin(documentVisibleRect.size.height, entry.contentSize.height))

      if remainingBoundsHeight <= -self.frame.size.height {
        newHeight = 0
      }

      if remainingContentHeight <= -self.frame.size.height {
        newHeight = 0
      }

      if newHeight > 0 {
        newHeight += padding.top + padding.bottom
      }

      frame.size.height = newHeight

      // Only scroll if the views content offset is less than its content size height
      // and if the frame is less than the content size height.
      let shouldScroll = round(contentOffset.y) <= round(entry.contentSize.height) &&
        round(frame.size.height) < round(entry.contentSize.height)

      if !(entry.view is NSCollectionView) {
        scrollView.contentOffset = CGPoint(x: 0, y: 0)
        if frame.origin.y != abs(round(entry.origin.y)) {
          frame.origin.y = abs(round(entry.origin.y))
        }
      } else if shouldScroll {
        if scrollView.contentOffset.y != contentOffset.y {
          scrollView.contentOffset = CGPoint(x: currentXOffset, y: contentOffset.y)
        }
      } else {
        if frame.origin.y != entry.origin.y {
          frame.origin.y = entry.origin.y
        }
        // Reset content offset to avoid setting offsets that
        // look liked `clipsToBounds` bugs.
        if self.contentOffset.y < entry.maxY && scrollView.contentOffset.y != 0 {
          scrollView.contentOffset = CGPoint(x: currentXOffset, y: 0)
        }
      }

      if scrollView.frame != frame {
        scrollView.frame = frame
      }
    }

    guard cache.state != .isFinished else { return }

    let computedHeight = yOffsetOfCurrentSubview
    let minimumContentHeight = bounds.height - (contentInsets.top + contentInsets.bottom)
    var height = abs(fmax(computedHeight, minimumContentHeight))
    cache.contentSize = CGSize(width: bounds.size.width, height: yOffsetOfCurrentSubview)

    if isChildViewController {
      height = computedHeight
      superview?.frame.size.height = cache.contentSize.height
    }

    documentView?.frame.size = CGSize(width: cache.contentSize.width, height: height)
    cache.state = .isFinished
  }

  private func contentSizeForView(_ view: NSView) -> CGSize {
    var contentSize: CGSize = .zero
    switch view {
    case let collectionView as NSCollectionView:
      if let flowLayout = collectionView.collectionViewLayout as? NSCollectionViewFlowLayout {
        contentSize = flowLayout.collectionViewContentSize
      }
    default:
      contentSize = view.frame.size
    }

    return contentSize
  }

  internal func compare(_ lhs: CGSize, to rhs: CGSize) -> Bool {
    return (abs(lhs.height - rhs.height) <= 0.001)
  }

  internal func compare(_ lhs: CGPoint, to rhs: CGPoint) -> Bool {
    return (abs(lhs.y - rhs.y) <= 0.001)
  }

  @objc func injected() {
    cache.invalidate()
    layoutViews(withDuration: nil, force: true, completion: nil)
  }
}

fileprivate extension NSCollectionView {
  var isHorizontal: Bool {
    return (collectionViewLayout as? NSCollectionViewFlowLayout)?.scrollDirection == .horizontal
  }
}

fileprivate extension NSScrollView {
  var isHorizontal: Bool {
    return (documentView as? NSCollectionView)?.isHorizontal ?? false
  }
}
