import Cocoa

public class FamilyScrollView: NSScrollView {
  public override var isFlipped: Bool { return true }
  public lazy var familyContentView: FamilyContentView = .init()
  public var spacingBetweenViews: CGFloat = 0
  private var subviewsInLayoutOrder = [NSScrollView]()

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    self.documentView = familyContentView
    self.drawsBackground = false

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
                          excludeOffscreenViews: Bool = true) {

    if NSAnimationContext.current.duration == 0.25 {
      NSAnimationContext.current.duration = 0.0
    }

    runLayoutSubviewsAlgorithm(
      withDuration: NSAnimationContext.current.duration,
      excludeOffscreenViews: excludeOffscreenViews
    )
    computeContentSize()

    DispatchQueue.main.asyncAfter(deadline: .now() + NSAnimationContext.current.duration) {
      NSAnimationContext.current.duration = 0.0
    }
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
      layoutViews()
    }
  }

  // MARK: - Window resizing

  fileprivate func processNewWindowSize(excludeOffscreenViews: Bool) {
    for case let familyView in subviewsInLayoutOrder {
      if let collectionView = familyView.documentView as? NSCollectionView {
        let visibleOnScreen = documentVisibleRect.intersects(familyView.frame)
        if excludeOffscreenViews && !visibleOnScreen {
          continue
        }

        collectionView.frame.size.width = self.frame.size.width
        collectionView.reloadData()
      }
    }
    layoutViews(excludeOffscreenViews: false)
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
  }

  public override func layout() {
    layoutViews()
    super.layout()
  }

  // MARK: - Private methods

  private func rebuildSubviewsInLayoutOrder(exceptSubview: View? = nil) {
    subviewsInLayoutOrder.removeAll()
    let filteredSubviews = familyContentView.scrollViews.filter({ !($0 === exceptSubview) })
    subviewsInLayoutOrder = filteredSubviews
  }

  private func runLayoutSubviewsAlgorithm(withDuration duration: CFTimeInterval? = nil,
                                          excludeOffscreenViews: Bool = true) {
    var yOffsetOfCurrentSubview: CGFloat = 0.0
    var offset = 0
    for scrollView in subviewsInLayoutOrder where scrollView.documentView != nil {
      var shouldResize: Bool = true
      let contentSize: CGSize = contentSizeForView(scrollView.documentView!, shouldResize: &shouldResize)
      var frame = scrollView.frame
      var contentOffset = scrollView.contentOffset

      if self.contentOffset.y < yOffsetOfCurrentSubview {
        contentOffset.y = 0
        frame.origin.y = yOffsetOfCurrentSubview
      } else {
        contentOffset.y = self.contentOffset.y - yOffsetOfCurrentSubview
        frame.origin.y = self.contentOffset.y
      }

      let remainingBoundsHeight = fmax(self.documentVisibleRect.maxY - frame.minY, 0.0)
      let remainingContentHeight = fmax(contentSize.height - contentOffset.y, 0.0)
      var newHeight: CGFloat = fmin(remainingBoundsHeight, remainingContentHeight)
      let shouldModifyContentOffset = contentOffset.y - contentInsets.top <= scrollView.contentSize.height + (contentInsets.top * 2) ||
        self.contentOffset.y != frame.minY

      if newHeight == 0 {
        newHeight = fmin(contentView.frame.height, scrollView.contentSize.height)
        if shouldModifyContentOffset && shouldResize {
          scrollView.contentOffset.y = contentOffset.y
        } else {
          frame.origin.y = yOffsetOfCurrentSubview
        }
      }

      frame.size.height = round(newHeight)
      frame.size.width = round(self.frame.size.width)

      setFrame(
        frame,
        withDuration: duration,
        contentSize: contentSize,
        shouldResize: shouldResize,
        currentYOffset: yOffsetOfCurrentSubview,
        to: scrollView
      )

      scrollView.contentView.scroll(contentOffset)
      yOffsetOfCurrentSubview += contentSize.height + spacingBetweenViews
      offset += 1
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
                        withDuration duration: CFTimeInterval? = nil,
                        contentSize: CGSize,
                        shouldResize: Bool,
                        currentYOffset: CGFloat,
                        to wrapperView: NSScrollView) {

    let instance: NSScrollView = wrapperView.animator()

    if shouldResize {
      instance.frame = frame
      instance.documentView?.frame.size.width = self.frame.width
      instance.documentView?.frame.size.height = contentSize.height
    } else {
      instance.documentView?.frame.size = contentSize
      instance.frame.size.height = contentSize.height
      instance.frame.size.width = self.frame.width
      instance.frame.origin.y = currentYOffset
    }
  }

  private func computeContentSize() {
    let computedHeight = subviewsInLayoutOrder.reduce(0, { $0 + ($1.documentView?.frame.size.height ?? 0) + spacingBetweenViews })
    let minimumContentHeight = bounds.height
    let height = fmax(computedHeight, minimumContentHeight)
    documentView?.frame.size = CGSize(width: bounds.size.width, height: height)
  }
}
