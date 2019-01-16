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

  public func layoutViews(withDuration duration: CFTimeInterval? = nil,
                          force: Bool = false,
                          completion: (() -> Void)? = nil) {
    guard isPerformingBatchUpdates == false else { return }

    guard !layoutIsRunning || !force else {
      return
    }

    if let duration = duration, duration > 0 {
      layoutIsRunning = true
      NSAnimationContext.runAnimationGroup({ (context) in
        context.duration = duration
        context.allowsImplicitAnimation = false
        runLayoutSubviewsAlgorithm()
      }, completionHandler: { [weak self] in
        self?.runLayoutSubviewsAlgorithm()
        self?.layoutIsRunning = false
        completion?()
      })
      return
    } else if isScrolling {
      NSAnimationContext.current.duration = 0.0
      NSAnimationContext.current.allowsImplicitAnimation = false
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
      layoutViews(withDuration: 0.0)
    }
  }

  func scrollTo(_ point: CGPoint, in view: NSView) {
    guard isScrollingByProxy,
      !isScrolling,
      !layoutIsRunning,
      view.window?.isVisible == true,
      let entry = cache.entry(for: view) else { return }
    var newOffset = CGPoint(x: self.contentOffset.x,
                            y: entry.origin.y + point.y)
    if newOffset.y < contentOffset.y {
      newOffset.y -= contentView.contentInsets.top
    }

    contentView.scroll(newOffset)
    // This is invoked to avoid animation stutter.
    contentView.scroll(to: newOffset)
    isScrollingByProxy = false
  }

  // MARK: - Window resizing

  private func processNewWindowSize(excludeOffscreenViews: Bool) {
    cache.invalidate()
    layoutViews(withDuration: 0.0, force: false)
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
    runLayoutSubviewsAlgorithm()
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

  public override func scrollWheel(with event: NSEvent) {
    super.scrollWheel(with: event)

    isScrolling = !(event.deltaX == 0 && event.deltaY == 0) ||
      !(event.phase == .ended || event.momentumPhase == .ended)
    isScrollingWithWheel = isScrolling

    layoutViews(withDuration: 0.0)
  }

  func wrapperViewDidChangeFrame(from fromValue: CGRect, to toValue: CGRect) {
    cache.invalidate()
    layoutViews(withDuration: 0.0, force: false)
  }

  // MARK: - Private methods

  private func rebuildSubviewsInLayoutOrder(exceptSubview: View? = nil) {
    subviewsInLayoutOrder.removeAll()
    subviewsInLayoutOrder = familyDocumentView.subviewsInLayoutOrder.filter({ !($0 === exceptSubview) })
  }

  private func validateScrollView(_ scrollView: NSScrollView) -> Bool {
    guard scrollView.documentView != nil else { return false }
    return scrollView.documentView?.isHidden == false && (scrollView.documentView?.alphaValue ?? 1.0) > CGFloat(0.0)
  }

  private func runLayoutSubviewsAlgorithm() {
    guard isPerformingBatchUpdates == false else { return }
    guard cache.state != .isRunning else { return }

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

        if self.contentOffset.y < yOffsetOfCurrentSubview {
          contentOffset.y = 0
          frame.origin.y = round(yOffsetOfCurrentSubview)
        } else {
          contentOffset.y = self.contentOffset.y - yOffsetOfCurrentSubview
          frame.origin.y = round(self.contentOffset.y)
        }

        let remainingBoundsHeight = fmax(self.documentVisibleRect.maxY - frame.minY, 0.0)
        let remainingContentHeight = fmax(contentSize.height - contentOffset.y, 0.0)
        var newHeight: CGFloat = fmin(remainingBoundsHeight, remainingContentHeight)

        if newHeight == 0 {
          newHeight = fmin(contentView.frame.height, scrollView.contentSize.height)
        }

        frame.origin.x = insets.left
        frame.size.height = newHeight
        frame.size.width = round(self.frame.size.width) - insets.left - insets.right

        scrollView.documentView?.frame.size.width = frame.width
        scrollView.documentView?.frame.size.height = contentSize.height
        scrollView.frame.origin.x = frame.origin.x
        scrollView.frame.size = frame.size

        cache.add(entry: FamilyViewControllerAttributes(view: scrollView.documentView!,
                                                        origin: CGPoint(x: frame.origin.x, y: yOffsetOfCurrentSubview),
                                                        contentSize: contentSize))
        yOffsetOfCurrentSubview += contentSize.height + insets.bottom
      }
      cache.contentSize = computeContentSize()
      documentView?.frame.size = cache.contentSize
      cache.state = .isFinished
    }

    let currentOffset = self.contentOffset.y + contentView.contentInsets.top
    let documentHeight = self.documentView!.frame.size.height

    // Reached the top
    guard currentOffset >= 0 else { return }

    // Reached the end
    guard self.documentVisibleRect.maxY <= documentHeight else { return }

    for scrollView in subviewsInLayoutOrder where validateScrollView(scrollView) {
      guard let entry = cache.entry(for: scrollView.documentView!) else { continue }
      var frame = scrollView.frame
      var contentOffset = scrollView.contentOffset

      if self.contentOffset.y < entry.origin.y {
        contentOffset.y = 0
        frame.origin.y = round(entry.origin.y)
      } else {
        contentOffset.y = self.contentOffset.y - entry.origin.y
        frame.origin.y = round(self.contentOffset.y)
      }

      let remainingBoundsHeight = fmax(self.documentVisibleRect.maxY - frame.minY, 0.0)
      let remainingContentHeight = fmax(entry.contentSize.height - contentOffset.y, 0.0)
      var newHeight: CGFloat = floor(fmin(remainingBoundsHeight, remainingContentHeight))

      if newHeight == 0 {
        newHeight = fmin(contentView.frame.height, scrollView.contentSize.height)
      }

      // Only scroll if the views content offset is less than its content size height
      // and if the frame is less than the content size height.
      let shouldScroll = contentOffset.y <= entry.contentSize.height &&
        frame.size.height < entry.contentSize.height

      if shouldScroll {
        scrollView.contentView.scroll(contentOffset)
        scrollView.frame.origin.y = frame.origin.y
        scrollView.frame.size.height = newHeight
      } else if scrollView.frame.origin.y != entry.origin.y {
        scrollView.frame.origin.y = entry.origin.y
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
    let computedHeight: CGFloat = subviewsInLayoutOrder
      .filter({ validateScrollView($0) })
      .reduce(CGFloat(0), { value, view in
        let insets = spaceManager.customInsets(for: (view as? FamilyWrapperView)?.view ?? view)
        return value + (view.documentView?.frame.size.height ?? 0) + insets.top + insets.bottom
      })
    let minimumContentHeight = bounds.height
    var height = fmax(computedHeight, minimumContentHeight)

    if computedHeight < minimumContentHeight {
      height -= contentInsets.top
    }

    return CGSize(width: bounds.size.width, height: height)
  }
}
