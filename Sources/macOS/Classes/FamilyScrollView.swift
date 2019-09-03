import Cocoa

public class FamilyScrollView: NSScrollView {
  public override var isFlipped: Bool { return true }

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

  var validRect: CGRect {
    var rect = documentVisibleRect
    let offset = bounds.size.height * 2
    rect.origin.y = max(self.contentOffset.y - (offset / 2), 0)
    rect.size.height = bounds.size.height + offset
    return rect
  }

  var discardableRect: CGRect {
    var rect = documentVisibleRect
    let offset = bounds.size.height * 2.5
    rect.origin.y = max(self.contentOffset.y - (offset / 2), 0)
    rect.size.height = bounds.size.height + offset
    return rect
  }

  @objc(scrollEnabled)
  public lazy var familyDocumentView = FamilyDocumentView()
  public var isScrollEnabled: Bool = true
  internal lazy var spaceManager = FamilySpaceManager()
  internal lazy var cache = FamilyCache()
  internal var backgrounds = [NSView: NSView]()
  internal var isDeallocating: Bool = false
  internal var isChildViewController: Bool = false
  internal var layoutIsRunning: Bool = false
  internal var isScrollingWithWheel: Bool = false
  internal var isScrolling: Bool = false
  internal var isScrollingByProxy: Bool = false
  internal var isPerformingBatchUpdates: Bool = false
  private var subviewsInLayoutOrder = [NSScrollView]()

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

    defer {
      // Clean up invalid views.
      if !isScrolling {
        for (offset, scrollView) in subviewsInLayoutOrder.enumerated() where scrollView.frame.size.height != 0 && !scrollView.frame.intersects(discardableRect) {
          scrollView.frame.size.height = 0
        }
      }
    }

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
    let center = NotificationCenter.default

    center.addObserver(
      self, selector: #selector(contentViewBoundsDidChange(_:)),
      name: NSView.boundsDidChangeNotification, object: contentView)

    center.addObserver(self,selector: #selector(windowDidResize(_:)),
                       name: NSWindow.didResizeNotification, object: nil)

    center.addObserver(self, selector: #selector(windowDidResize(_:)),
                       name: NSSplitView.didResizeSubviewsNotification, object: nil)

    center.addObserver(self, selector: #selector(windowDidResize(_:)),
                       name: NSSplitView.willResizeSubviewsNotification, object: nil)

    center.addObserver(self, selector: #selector(windowDidEndLiveResize(_:)),
                       name: NSWindow.didEndLiveResizeNotification, object: nil)

    center.addObserver(self, selector: #selector(didLiveScroll),
                       name: NSScrollView.didLiveScrollNotification, object: nil)

    center.addObserver(self, selector: #selector(didEndLiveScroll),
                       name: NSScrollView.didEndLiveScrollNotification, object: nil)
  }

  @objc func didLiveScroll() { isScrolling = true }
  @objc func didEndLiveScroll() { isScrolling = false; isScrollingWithWheel = false }

  @objc func contentViewBoundsDidChange(_ notification: NSNotification) {
    if (notification.object as? NSClipView) === contentView,
      let window = window, !window.inLiveResize,
      !isScrollingWithWheel {
      layoutViews(withDuration: 0.0, force: false, completion: nil)
    }
  }

  func scrollTo(_ point: CGPoint, in view: NSView) {
    let shouldScrollByProxy = isScrollingByProxy &&
      !isScrolling && !layoutIsRunning &&
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
    if backgrounds[view] != nil { backgrounds[view]?.removeFromSuperview() }
    backgrounds[view] = backgroundView
    familyDocumentView.addSubview(backgroundView, positioned: .below, relativeTo: view)
    cache.invalidate()
    guard !isPerformingBatchUpdates else { return }
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
    guard !isPerformingBatchUpdates else { return }
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
    guard !isPerformingBatchUpdates else { return }
    layoutViews(withDuration: nil, force: false, completion: nil)
  }

  public func margins(for view: View) -> Insets {
    return spaceManager.margins(for: view)
  }

  public func addMargins(_ insets: Insets, for view: View) {
    spaceManager.addMargins(insets, for: view)
    cache.invalidate()
    guard !isPerformingBatchUpdates else { return }
    layoutViews(withDuration: nil, force: false, completion: nil)
  }

  /// Remove wrapper views that don't own their underlaying views.
  func purgeWrapperViews() {
    for case let wrapperView as FamilyWrapperView in familyDocumentView.subviews where wrapperView != wrapperView.view.enclosingScrollView {
      wrapperView.removeFromSuperview()
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

    // Exclude empty collection views.
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

  // MARK: - Layout Algorithm

  func getValidAttributes(in rect: CGRect) -> [FamilyViewControllerAttributes] {
    let binarySearch = BinarySearch()
    let upper: (FamilyViewControllerAttributes) -> Bool = { attributes in
      let frame = attributes.scrollView.layer?.presentation()?.frame ?? attributes.scrollView.frame
      return attributes.frame.maxY >= rect.minY ||
        frame.maxY >= rect.minY
    }
    let lower: (FamilyViewControllerAttributes) -> Bool = { attributes in
      let frame = attributes.scrollView.layer?.presentation()?.frame ?? attributes.scrollView.frame
      return attributes.frame.minY <= rect.maxY ||
        frame.minY <= rect.maxY
    }
    let less: (FamilyViewControllerAttributes) -> Bool =  { attributes in
      let frame = attributes.scrollView.layer?.presentation()?.frame ?? attributes.scrollView.frame
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

  private func runLayoutSubviewsAlgorithm() {
    guard isPerformingBatchUpdates == false, !isDeallocating,
      cache.state != .isRunning else { return }

    var scrollViewContentOffset = self.contentOffset

    if cache.state == .empty {
      var yOffsetOfCurrentSubview: CGFloat = 0.0
      for scrollView in subviewsInLayoutOrder where validateScrollView(scrollView) {
        guard let view = scrollView.documentView else { continue }
        let contentSize: CGSize = contentSizeForView(view)
        let padding = spaceManager.padding(for: view)
        let margins = spaceManager.margins(for: view)
        let constrainedWidth = round(self.frame.size.width) - margins.left - margins.right - padding.left - padding.right
        let currentXOffset = scrollView.isHorizontal ? scrollView.contentOffset.x : margins.left
        var frame = scrollView.frame
        var viewFrame = frame

        yOffsetOfCurrentSubview += margins.top

        frame.origin.y = yOffsetOfCurrentSubview
        frame.origin.x = currentXOffset
        frame.size.height = min(visibleRect.height, contentSize.height)
        frame.size.width = round(self.frame.size.width) - margins.left - margins.right

        if !frame.intersects(documentVisibleRect) {
          frame.size.height = 0
        }

        if view is NSCollectionView {
          viewFrame.origin.x = padding.left
          viewFrame.origin.y = padding.top
        } else {
          scrollView.automaticallyAdjustsContentInsets = false
          scrollView.contentInsets = padding
          frame.size.height += padding.top + padding.bottom
        }

        viewFrame.size.width = scrollView.isHorizontal ? contentSize.width : constrainedWidth
        viewFrame.size.height = contentSize.height

        view.frame = viewFrame
        scrollView.frame = frame

        let origin = CGPoint(x: frame.origin.x, y: yOffsetOfCurrentSubview)
        let entry = FamilyViewControllerAttributes(view: view, origin: origin,
                                                   contentSize: contentSize)

        if scrollView.frame != frame {
          scrollView.frame = frame
        }

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

        let previousContentOffset = self.contentOffset
        self.contentOffset = previousContentOffset
      }

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

    let validAttributes = getValidAttributes(in: discardableRect)
    for attributes in validAttributes where validateScrollView(attributes.scrollView) {
      let scrollView = attributes.scrollView
      let view = attributes.view
      let padding = spaceManager.padding(for: view)
      let currentXOffset = scrollView.isHorizontal ? scrollView.contentOffset.x : 0
      var frame = scrollView.frame
      var contentOffset = scrollView.contentOffset

      // Constrain the computed offset to be inside of document visible rect.
      scrollViewContentOffset.y = min(documentVisibleRect.origin.y + contentInsets.top,
                                      cache.contentSize.height - documentVisibleRect.size.height + contentInsets.top)

      if self.contentOffset.y < attributes.origin.y {
        contentOffset.y = 0
        frame.origin.y = abs(attributes.origin.y)
      } else {
        contentOffset.y = abs(scrollViewContentOffset.y - attributes.origin.y)
        frame.origin.y = abs(scrollViewContentOffset.y)
      }

      var newHeight: CGFloat = abs(fmin(documentVisibleRect.size.height, attributes.contentSize.height))

      if !attributes.frame.intersects(validRect) {
        newHeight = 0
      }

      // Only add padding if the new height exceeds zero.
      if newHeight > 0 {
        newHeight += padding.top + padding.bottom
      }

      // Only scroll if the views content offset is less than its content size height
      // and if the frame is less than the content size height.
      let shouldScroll = round(contentOffset.y) <= round(attributes.contentSize.height) &&
        round(frame.size.height) < round(attributes.contentSize.height)

      if !(attributes.view is NSCollectionView) {
        if frame.origin.y != abs(round(attributes.origin.y)) {
          frame.origin.y = abs(round(attributes.origin.y))
        }
      } else if shouldScroll {
        if scrollView.contentOffset.y != contentOffset.y {
          scrollView.contentOffset = CGPoint(x: currentXOffset, y: contentOffset.y)
        }
      } else {
        if (abs(frame.origin.y - frame.origin.y) <= 0.001) {
          frame.origin.y = attributes.origin.y
        }
        // Reset content offset to avoid setting offsets that
        // look like `clipsToBounds` bugs.
        if self.contentOffset.y < attributes.maxY && scrollView.contentOffset.y != 0 {
          scrollView.contentOffset = CGPoint(x: currentXOffset, y: 0)
        }
      }

      frame.size.height = newHeight
      if scrollView.frame != frame {
        scrollView.frame = frame
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

  internal func compare(_ lhs: CGRect, to rhs: CGRect) -> Bool {
    return (abs(lhs.size.height - rhs.size.height) <= 0.001) &&
      (abs(lhs.size.width - rhs.size.width) <= 0.001) &&
      (abs(lhs.origin.y - rhs.origin.y) <= 0.001) &&
      (abs(lhs.origin.x - rhs.origin.x) <= 0.001)
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
