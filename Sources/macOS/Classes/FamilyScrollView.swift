import Cocoa

class FamilyCache: NSObject {
  var contentSize: CGSize = .zero
  var cache = [NSView: CacheEntry]()
  var isEmpty: Bool { return cache.isEmpty }
  override init() {}

  func add(entry: CacheEntry) {
    cache[entry.view] = entry
  }

  func entry(for view: NSView) -> CacheEntry? {
    return cache[view]
  }

  func clear() {
    cache.removeAll()
  }
}

class CacheEntry: NSObject {
  var view: NSView
  var origin: CGPoint
  var contentSize: CGSize

  init(view: NSView, origin: CGPoint, contentSize: CGSize) {
    self.view = view
    self.origin = origin
    self.contentSize = contentSize
  }
}

public class FamilyScrollView: NSScrollView {
  public override var isFlipped: Bool { return true }
  public lazy var familyContentView: FamilyContentView = .init()
  public var spacing: CGFloat {
    get { return spaceManager.spacing }
    set {
      spaceManager.spacing = newValue
      cache.clear()
    }
  }
  var layoutIsRunning: Bool = false
  var isScrolling: Bool = false
  private var subviewsInLayoutOrder = [NSScrollView]()
  private lazy var spaceManager = FamilySpaceManager()
  lazy var cache = FamilyCache()

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    self.documentView = familyContentView
    self.drawsBackground = false
    self.familyContentView.familyScrollView = self
    configureObservers()
    hasVerticalScroller = true
    contentView.postsBoundsChangedNotifications = true
    familyContentView.autoresizingMask = [.width]
  }

  required public init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
    familyContentView.subviews.forEach { $0.removeFromSuperview() }
    subviewsInLayoutOrder.forEach { $0.removeFromSuperview() }
    subviewsInLayoutOrder.removeAll()
  }

  // MARK: - Public methods

  public func layoutViews(withDuration duration: CFTimeInterval? = nil,
                          force: Bool = false) {
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
      })
      return
    } else if isScrolling {
      NSAnimationContext.current.duration = 0.0
      NSAnimationContext.current.allowsImplicitAnimation = false
    }

    layoutIsRunning = true
    runLayoutSubviewsAlgorithm()
    layoutIsRunning = false
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
      selector: #selector(windowDidEndLiveResize(_:)),
      name: NSWindow.didEndLiveResizeNotification,
      object: nil
    )
  }

  @objc func contentViewBoundsDidChange(_ notification: NSNotification) {
    if (notification.object as? NSClipView) === contentView,
      let window = window,
      !window.inLiveResize {
      layoutViews(withDuration: 0.0)
    }
  }

  // MARK: - Window resizing

  private func processNewWindowSize(excludeOffscreenViews: Bool) {
    cache.clear()
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
    if familyContentView.scrollViews.index(of: scrollView) != nil {
      rebuildSubviewsInLayoutOrder()
      subviewsInLayoutOrder.removeAll()

      for scrollView in familyContentView.scrollViews {
        subviewsInLayoutOrder.append(scrollView)
      }
    }
    runLayoutSubviewsAlgorithm()
    cache.clear()
  }

  func didRemoveScrollViewToContainer(_ subview: NSView) {
    cache.clear()
  }

  public func customSpacing(after view: View) -> CGFloat {
    return spaceManager.customSpacing(after: view)
  }

  public func setCustomSpacing(_ spacing: CGFloat, after view: View) {
    spaceManager.setCustomSpacing(spacing, after: view)
    cache.clear()
  }

  public override func scrollWheel(with event: NSEvent) {
    super.scrollWheel(with: event)

    isScrolling = !(event.deltaX == 0 && event.deltaY == 0) ||
      !(event.phase == .ended || event.momentumPhase == .ended)

    layoutViews(withDuration: 0.0)
  }

  func wrapperViewDidChangeFrame(from fromValue: CGRect, to toValue: CGRect) {
    cache.clear()
    layoutViews(withDuration: 0.0, force: false)
  }

  // MARK: - Private methods

  private func rebuildSubviewsInLayoutOrder(exceptSubview: View? = nil) {
    subviewsInLayoutOrder.removeAll()
    let filteredSubviews = familyContentView.scrollViews.filter({ !($0 === exceptSubview) })
    subviewsInLayoutOrder = filteredSubviews
  }

  private func validateScrollView(_ scrollView: NSScrollView) -> Bool {
    guard scrollView.documentView != nil else { return false }
    return scrollView.documentView?.isHidden == false && (scrollView.documentView?.alphaValue ?? 1.0) > CGFloat(0.0)
  }

  private func runLayoutSubviewsAlgorithm() {
    if cache.isEmpty {
      var yOffsetOfCurrentSubview: CGFloat = 0.0
      var offset = 0
      for scrollView in subviewsInLayoutOrder where validateScrollView(scrollView) {
        var shouldResize: Bool = true
        let contentSize: CGSize = contentSizeForView(scrollView.documentView!, shouldResize: &shouldResize)
        var frame = scrollView.frame
        var contentOffset = scrollView.contentOffset

        if self.contentOffset.y < yOffsetOfCurrentSubview {
          contentOffset.y = 0
          frame.origin.y = floor(yOffsetOfCurrentSubview)
        } else {
          contentOffset.y = self.contentOffset.y - yOffsetOfCurrentSubview
          frame.origin.y = floor(self.contentOffset.y)
        }

        let remainingBoundsHeight = fmax(self.documentVisibleRect.maxY - frame.minY, 0.0)
        let remainingContentHeight = fmax(contentSize.height - contentOffset.y, 0.0)
        var newHeight: CGFloat = fmin(remainingBoundsHeight, remainingContentHeight)

        frame.size.width = max(frame.size.width, self.frame.size.width)

        let shouldModifyContentOffset = contentOffset.y - contentInsets.top <= scrollView.contentSize.height + (contentInsets.top * 2) ||
          self.contentOffset.y != frame.minY

        if newHeight == 0 {
          newHeight = fmin(contentView.frame.height, scrollView.contentSize.height)
          if shouldModifyContentOffset && shouldResize {
            scrollView.contentOffset.y = contentOffset.y
          } else {
            frame.origin.y = yOffsetOfCurrentSubview
          }
        } else if remainingContentHeight < contentSize.height {
          frame.origin.y = self.contentOffset.y - (contentSize.height - remainingContentHeight)
          shouldResize = false
        }

        frame.size.height = round(newHeight)
        frame.size.width = round(self.frame.size.width)

        setFrame(
          frame,
          contentSize: contentSize,
          shouldResize: shouldResize,
          currentYOffset: yOffsetOfCurrentSubview,
          to: scrollView
        )

        scrollView.contentView.scroll(contentOffset)

        let view = (scrollView as? FamilyWrapperView)?.view ?? scrollView
        yOffsetOfCurrentSubview += contentSize.height + spaceManager.customSpacing(after: view)
        offset += 1
        cache.add(entry: CacheEntry.init(view: scrollView.documentView!, origin: frame.origin, contentSize: contentSize))
      }
      computeContentSize()
    } else {
      let currentOffset = self.contentOffset.y + contentView.contentInsets.top
      let maxOffset = self.contentOffset.y + self.frame.size.height
      let documentHeight = self.documentView!.frame.size.height

      // Reached the top
      guard currentOffset >= 0 else { return }

      // Reached the end
      guard maxOffset <= documentHeight else { return }

      for scrollView in subviewsInLayoutOrder where validateScrollView(scrollView) {
        let documentView = scrollView.documentView!
        guard let entry = cache.entry(for: documentView) else { continue }
        var frame = scrollView.frame
        var contentOffset = scrollView.contentOffset

        if self.contentOffset.y < entry.origin.y {
          contentOffset.y = 0
          frame.origin.y = floor(entry.origin.y)
        } else {
          contentOffset.y = self.contentOffset.y - entry.origin.y
          frame.origin.y = floor(self.contentOffset.y)
        }

        let remainingBoundsHeight = fmax(self.documentVisibleRect.maxY - frame.minY, 0.0)
        let remainingContentHeight = fmax(entry.contentSize.height - contentOffset.y, 0.0)
        var newHeight: CGFloat = floor(fmin(remainingBoundsHeight, remainingContentHeight))

        if newHeight == 0 {
          newHeight = fmin(contentView.frame.height, scrollView.contentSize.height)
        }

        if contentOffset.y <= entry.contentSize.height {
          scrollView.contentView.scroll(contentOffset)
          scrollView.frame.origin.y = frame.origin.y
          if scrollView.frame.size.height != newHeight {
            scrollView.frame.size.height = newHeight
          }
        } else if scrollView.frame.origin.y != entry.origin.y {
          scrollView.frame.origin.y = entry.origin.y
        }
      }
    }
  }

  private func contentSizeForView(_ view: NSView, shouldResize: inout Bool) -> CGSize {
    var contentSize: CGSize = .zero
    switch view {
    case let collectionView as NSCollectionView:
      if let flowLayout = collectionView.collectionViewLayout as? NSCollectionViewFlowLayout {
        shouldResize = flowLayout.scrollDirection == .vertical
        contentSize = flowLayout.collectionViewContentSize
      }
    default:
      contentSize = view.frame.size
    }

    return contentSize
  }

  private func setFrame(_ frame: NSRect,
                        contentSize: CGSize,
                        shouldResize: Bool,
                        currentYOffset: CGFloat,
                        to wrapperView: NSScrollView) {

    if shouldResize {
      wrapperView.documentView?.frame.size.width = frame.width
      wrapperView.documentView?.frame.size.height = contentSize.height
      wrapperView.frame = frame
    } else {
      wrapperView.documentView?.frame.size.width = max(contentSize.width, frame.width)
      wrapperView.documentView?.frame.size.height = contentSize.height
      wrapperView.frame.size.height = contentSize.height
      wrapperView.frame.size.width = frame.width
      wrapperView.frame.origin.y = currentYOffset
    }
  }

  private func computeContentSize() {
    let computedHeight: CGFloat = subviewsInLayoutOrder
      .filter({ validateScrollView($0) })
      .reduce(0, { $0 + ($1.documentView?.frame.size.height ?? 0) + spaceManager.customSpacing(after: ($1 as? FamilyWrapperView)?.view ?? $1) })
    let minimumContentHeight = bounds.height
    var height = fmax(computedHeight, minimumContentHeight)

    if computedHeight < minimumContentHeight {
      height -= contentInsets.top
    }

    cache.contentSize = documentView!.frame.size
    documentView?.frame.size = CGSize(width: bounds.size.width, height: height)
  }
}
