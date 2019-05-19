import Cocoa

public class FamilyScrollView: NSScrollView {
  public override var isFlipped: Bool { return true }
  public lazy var familyDocumentView: FamilyDocumentView = .init()
  public var insets: Insets {
    get { return spaceManager.insets }
    set {
      spaceManager.insets = newValue
      cache.invalidate()
    }
  }

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
  private lazy var spaceManager = FamilySpaceManager()
  lazy var cache = FamilyCache()

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    self.documentView = familyDocumentView
    self.drawsBackground = false
    self.familyDocumentView.familyScrollView = self
    configureObservers()
    hasVerticalScroller = true
    contentView.postsBoundsChangedNotifications = true
    familyDocumentView.autoresizingMask = [.width]
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
      NSAnimationContext.endGrouping()
    }

    layoutIsRunning = true
    runLayoutSubviewsAlgorithm()
    layoutIsRunning = false
    completion?()
  }

  // MARK: - Observers

  private func configureObservers() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(contentViewBoundsDidChange(_:)),
      name: NSView.boundsDidChangeNotification,
      object: contentView
    )

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(windowDidResize(_:)),
      name: NSWindow.didResizeNotification,
      object: nil
    )

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(windowDidResize(_:)),
      name: NSSplitView.didResizeSubviewsNotification,
      object: nil
    )

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(windowDidEndLiveResize(_:)),
      name: NSWindow.didEndLiveResizeNotification,
      object: nil
    )

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(didLiveScroll),
      name: NSScrollView.didLiveScrollNotification,
      object: nil
    )

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(didEndLiveScroll),
      name: NSScrollView.didEndLiveScrollNotification,
      object: nil
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

  private func processNewWindowSize(excludeOffscreenViews: Bool) {
    guard window != nil else { return }
    cache.invalidate()
    layoutViews(withDuration: 0.0, force: false, completion: nil)
  }

  @objc open func windowDidResize(_ notification: Notification) {
    processNewWindowSize(excludeOffscreenViews: true)
  }

  @objc public func windowDidEndLiveResize(_ notification: Notification) {
    processNewWindowSize(excludeOffscreenViews: false)
  }

  public override func viewWillMove(toSuperview newSuperview: NSView?) {
    super.viewWillMove(toSuperview: newSuperview)

    if let newSuperview = newSuperview {
      frame.size = newSuperview.frame.size
      documentView?.frame.size = .zero
    }
  }

  func didAddScrollViewToContainer(_ scrollView: NSScrollView) {
    if familyDocumentView.scrollViews.index(of: scrollView) != nil {
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
    cache.invalidate()
  }

  public func customInsets(for view: View) -> Insets {
    return spaceManager.customInsets(for: view)
  }

  public func setCustomInsets(_ insets: Insets, for view: View) {
    spaceManager.setCustomInsets(insets, for: view)
    cache.invalidate()
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

  private func runLayoutSubviewsAlgorithm() {
    guard isPerformingBatchUpdates == false,
      !isDeallocating,
      cache.state != .isRunning else { return }

    var scrollViewContentOffset = self.contentOffset

    if cache.state == .empty {
      cache.state = .isRunning
      var yOffsetOfCurrentSubview: CGFloat = 0.0
      for scrollView in subviewsInLayoutOrder where validateScrollView(scrollView) {
        let view = (scrollView as? FamilyWrapperView)?.view ?? scrollView
        let contentSize: CGSize = contentSizeForView(view)
        let insets = spaceManager.customInsets(for: view)
        yOffsetOfCurrentSubview += insets.top
        var frame = scrollView.frame
        var contentOffset = scrollView.contentOffset

        scrollViewContentOffset.y = min(documentVisibleRect.origin.y,
                                        contentSize.height - documentVisibleRect.size.height)

        if self.contentOffset.y < yOffsetOfCurrentSubview {
          contentOffset.y = 0
          frame.origin.y = round(yOffsetOfCurrentSubview)
        } else {
          contentOffset.y = scrollViewContentOffset.y - yOffsetOfCurrentSubview
          frame.origin.y = round(scrollViewContentOffset.y)
        }

        let remainingBoundsHeight = fmax(documentVisibleRect.maxY - frame.minY, 0.0)
        let remainingContentHeight = fmax(contentSize.height - contentOffset.y, 0.0)
        var newHeight: CGFloat = abs(fmin(documentVisibleRect.size.height, contentSize.height))

        if remainingBoundsHeight <= -self.frame.size.height {
          newHeight = 0
        }

        if remainingContentHeight <= -self.frame.size.height {
          newHeight = 0
        }

        frame.origin.y = yOffsetOfCurrentSubview
        frame.origin.x = insets.left
        frame.size.height = newHeight
        frame.size.width = round(self.frame.size.width) - insets.left - insets.right

        // Opt-out from setting new document size to NSCollectionView and check that we don't set
        // the same size more than once.
        if !(scrollView.documentView is NSCollectionView) &&
          scrollView.documentView?.frame.size != CGSize(width: frame.size.width, height: contentSize.height) {
          scrollView.documentView?.frame.size = CGSize(width: frame.size.width, height: contentSize.height)
        }

        if scrollView.documentView!.frame.size.width != frame.width {
          scrollView.documentView!.frame.size.width = frame.width
        }

        cache.add(entry: FamilyViewControllerAttributes(view: scrollView.documentView!,
                                                        origin: CGPoint(x: frame.origin.x, y: yOffsetOfCurrentSubview),
                                                        contentSize: contentSize))
        yOffsetOfCurrentSubview += contentSize.height + insets.bottom
      }
      cache.contentSize = computeContentSize()
      documentView?.frame.size = cache.contentSize
      cache.state = .isFinished
    }

    for scrollView in subviewsInLayoutOrder where validateScrollView(scrollView) {
      guard let entry = cache.entry(for: scrollView.documentView!) else { continue }
      let insets = spaceManager.customInsets(for: scrollView.documentView!)
      var frame = scrollView.frame
      var contentOffset = scrollView.contentOffset

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

      let remainingBoundsHeight = fmax(documentVisibleRect.maxY - frame.minY, 0.0)
      let remainingContentHeight = fmax(entry.contentSize.height - contentOffset.y, 0.0)
      var newHeight: CGFloat = abs(fmin(documentVisibleRect.size.height, entry.contentSize.height))

      if remainingBoundsHeight <= -self.frame.size.height {
        newHeight = 0
      }

      if remainingContentHeight <= -self.frame.size.height {
        newHeight = 0
      }

      // Only scroll if the views content offset is less than its content size height
      // and if the frame is less than the content size height.
      let shouldScroll = contentOffset.y <= entry.contentSize.height &&
        frame.size.height < entry.contentSize.height

      if scrollView.frame.origin.x != insets.left {
        frame.origin.x = insets.left
      }

      let viewWidth = round(self.frame.size.width) - insets.left - insets.right
      if scrollView.frame.size.width != viewWidth {
        frame.size.width = viewWidth
      }

      if !(entry.view is NSCollectionView) {
        if self.contentOffset.y < entry.origin.y {
          scrollView.contentOffset.y = contentOffset.y
        } else {
          frame.origin.y = entry.origin.y
        }
      } else if shouldScroll {
        scrollView.frame.origin.y = frame.origin.y
        scrollView.contentOffset.y = contentOffset.y
        scrollView.frame.size.height = newHeight
      } else {
        frame.origin.y = entry.origin.y
        // Reset content offset to avoid setting offsets that
        // look liked `clipsToBounds` bugs.
        if self.contentOffset.y < entry.maxY {
          scrollView.contentOffset.y = 0
        }
      }

      if compare(scrollView.frame.origin, to: frame.origin) ||
        compare(scrollView.frame.size, to: frame.size) {
        scrollView.frame = frame
        scrollView.documentView?.frame.size.height = entry.contentSize.height
      }
    }
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

  private func computeContentSize() -> CGSize {
    let validSubviews = subviewsInLayoutOrder
      .filter({ validateScrollView($0) })

    var computedHeight: CGFloat = validSubviews.reduce(CGFloat(0), { value, view in
      return value + contentSizeForView(view.documentView ?? view).height
    })

    let computedInsets: CGFloat = validSubviews.reduce(CGFloat(0), { value, view in
      let insets = spaceManager.customInsets(for: view.documentView ?? view)
      return value + insets.top + insets.bottom
    })

    computedHeight += computedInsets

    let minimumContentHeight = bounds.height
    var height = fmax(computedHeight, minimumContentHeight)

    if computedHeight <= minimumContentHeight {
      height -= contentInsets.top
    }

    if isChildViewController {
      height = computedHeight
      superview?.frame.size.height = computedHeight
    }

    return CGSize(width: bounds.size.width, height: height)
  }

  internal func compare(_ lhs: CGSize, to rhs: CGSize) -> Bool {
    return (abs(lhs.height - rhs.height) <= 0.001)
  }

  internal func compare(_ lhs: CGPoint, to rhs: CGPoint) -> Bool {
    return (abs(lhs.y - rhs.y) <= 0.001)
  }
}
