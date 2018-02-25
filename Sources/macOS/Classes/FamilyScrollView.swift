import Cocoa

public class FamilyScrollView: NSScrollView {
  public override var isFlipped: Bool { return true }
  public lazy var familyContentView: FamilyContentView = .init()
  public var spacingBetweenViews: CGFloat = 0
  private var observers = [Observer]()
  private var subviewsInLayoutOrder = [NSScrollView]()

  var observer: NSKeyValueObservation?

  private struct Observer: Equatable {
    let view: NSView
    let keyValueObservation: NSKeyValueObservation

    static func == (lhs: Observer, rhs: Observer) -> Bool {
      return lhs.view === rhs.view && lhs.keyValueObservation === rhs.keyValueObservation
    }
  }

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

  deinit {
    NotificationCenter.default.removeObserver(self)
    subviewsInLayoutOrder.removeAll()
    observers.removeAll()
  }

  // MARK: - Observers

  @objc func contentViewBoundsDidChange(_ notification: NSNotification) {
    if (notification.object as? NSClipView) === contentView,
      let window = window,
      !window.inLiveResize {
      layoutViews()
    }
  }

  fileprivate func processNewWindowSize(excludeOffscreenViews: Bool) {
    for case let familyView as FamilyWrapperView in subviewsInLayoutOrder {
      if let collectionView = familyView.wrappedView as? NSCollectionView,
        let flowLayout = collectionView.collectionViewLayout as? NSCollectionViewFlowLayout {

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

  func didAddScrollViewToContainer(_ scrollView: NSScrollView) {
    guard familyContentView.scrollViews.index(of: scrollView) != nil else {
      return
    }

    rebuildSubviewsInLayoutOrder()
    subviewsInLayoutOrder.removeAll()

    for scrollView in familyContentView.scrollViews {
      subviewsInLayoutOrder.append(scrollView)
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
    let isResizing = window?.inLiveResize ?? false
    let multipleComponents = subviewsInLayoutOrder.count > 1
    var yOffsetOfCurrentSubview: CGFloat = 0.0
    var offset = 0
    for case let familyWrapper as FamilyWrapperView in subviewsInLayoutOrder {
      guard let documentView: View = familyWrapper.documentView else {
        return
      }

      var shouldResize: Bool = true
      var shouldScroll: Bool = true
      var contentSize: CGSize = contentSizeForView(documentView, shouldResize: &shouldResize)
      var frame = familyWrapper.frame
      var contentOffset = familyWrapper.contentOffset

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
      let shouldModifyContentOffset = contentOffset.y - contentInsets.top <= familyWrapper.contentSize.height + (contentInsets.top * 2) ||
        self.contentOffset.y != frame.minY

      if newHeight == 0 {
        newHeight = fmin(contentView.frame.height, familyWrapper.contentSize.height)
        if shouldModifyContentOffset && shouldResize {
          familyWrapper.contentOffset.y = contentOffset.y
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
        to: familyWrapper
      )

      familyWrapper.contentView.scroll(contentOffset)
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
                        to wrapperView: FamilyWrapperView) {

    let instance: FamilyWrapperView
    if let duration = duration {
      instance = wrapperView.animator()
    } else {
      instance = wrapperView
    }

    if shouldResize {
      instance.frame = frame
      instance.documentView?.frame.size.width = self.frame.width
      instance.documentView?.frame.size.height = contentSize.height
    } else {
      instance.documentView?.frame.size = contentSize
      instance.frame.size.width = self.frame.width
      instance.frame.origin.y = currentYOffset
    }
  }

  private func computeContentSize() {
    let computedHeight = subviewsInLayoutOrder.reduce(0, { $0 + $1.documentView!.frame.size.height + spacingBetweenViews })
    let minimumContentHeight = bounds.height
    let height = fmax(computedHeight, minimumContentHeight)
    documentView?.frame.size = CGSize(width: bounds.size.width, height: height)
  }

  private func determineSizeForView(_ view: NSView) -> CGSize {
    switch view {
    case let collectionView as NSCollectionView:
      let layout = collectionView.collectionViewLayout!
      return layout.collectionViewContentSize
    default:
      return CGSize(width: self.frame.size.width, height: view.frame.size.height)
    }
  }
}
