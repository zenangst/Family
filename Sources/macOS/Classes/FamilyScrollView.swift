import Cocoa

public class BinarySearch {
  public init() {}

  private func binarySearch(_ collection: [NSView],
                            less: (NSView) -> Bool,
                            match: (NSView) -> Bool) -> Int? {
    var lowerBound = 0
    var upperBound = collection.count

    while lowerBound < upperBound {
      let midIndex = lowerBound + (upperBound - lowerBound) / 2
      let element = collection[midIndex]

      if match(element) {
        return midIndex
      } else if less(element) {
        lowerBound = midIndex + 1
      } else {
        upperBound = midIndex
      }
    }

    return nil
  }

  public func findElement(in collection: [NSView],
                          less: (NSView) -> Bool,
                          match: (NSView) -> Bool) -> NSView? {
    guard let firstMatchIndex = binarySearch(collection, less: less, match: match) else {
      return nil
    }
    return collection[firstMatchIndex]
  }

  public func findElements(in collection: [NSView],
                           less: (NSView) -> Bool,
                           match: (NSView) -> Bool) -> [NSView]? {
    guard let firstMatchIndex = binarySearch(collection, less: less, match: match) else {
      return nil
    }

    var results = [NSView]()

    for element in collection[..<firstMatchIndex].reversed() {
      guard match(element) else { break }
      results.append(element)
    }

    for element in collection[firstMatchIndex...] {
      guard match(element) else { break }
      results.append(element)
    }

    return results
  }
}

public class FamilyScrollView: NSScrollView {
  public override var isFlipped: Bool { return true }
  public lazy var familyContentView: FamilyContentView = .init()
  public var spacing: CGFloat {
    get { return spaceManager.spacing }
    set { spaceManager.spacing = newValue }
  }
  var layoutIsRunning: Bool = false
  var isScrolling: Bool = false
  let binarySearch = BinarySearch()
  private var subviewsInLayoutOrder = [NSView]()
  private lazy var spaceManager = FamilySpaceManager()

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
                          excludeOffscreenViews: Bool = true) {
    guard !layoutIsRunning else {
      return
    }

    CATransaction.begin()
    defer { CATransaction.commit() }

    if let duration = duration, duration > 0 {
      layoutIsRunning = true
      NSAnimationContext.runAnimationGroup({ (context) in
        context.duration = duration
        context.allowsImplicitAnimation = true
        runLayoutSubviewsAlgorithm(useBinarySearch: true)
      }, completionHandler: { [weak self] in
        self?.computeContentSize()
        self?.runLayoutSubviewsAlgorithm()
        self?.layoutIsRunning = false
      })
      return
    } else if isScrolling {
      CATransaction.setDisableActions(true)
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
    runLayoutSubviewsAlgorithm(useBinarySearch: true)
  }

  // MARK: - Window resizing

  @objc open func windowDidResize(_ notification: Notification) {
    runLayoutSubviewsAlgorithm()
  }

  @objc public func windowDidEndLiveResize(_ notification: Notification) {
    runLayoutSubviewsAlgorithm()
  }

  public override func viewWillMove(toSuperview newSuperview: NSView?) {
    super.viewWillMove(toSuperview: newSuperview)

    if let newSuperview = newSuperview {
      frame.size = newSuperview.frame.size
      documentView?.frame.size = .zero
    }
  }

  func didAddScrollViewToContainer(_ view: NSView) {
    if familyContentView.subviews.index(of: view) != nil {
      rebuildSubviewsInLayoutOrder()
      subviewsInLayoutOrder.removeAll()

      for scrollView in familyContentView.subviews {
        subviewsInLayoutOrder.append(scrollView)
      }
    }
    runLayoutSubviewsAlgorithm(useBinarySearch: false)
    computeContentSize()
  }

  public func customSpacing(after view: View) -> CGFloat {
    return spaceManager.customSpacing(after: view)
  }

  public func setCustomSpacing(_ spacing: CGFloat, after view: View) {
    spaceManager.setCustomSpacing(spacing, after: view)
  }

  // MARK: - Private methods

  private func rebuildSubviewsInLayoutOrder(exceptSubview: View? = nil) {
    subviewsInLayoutOrder.removeAll()
    let filteredSubviews = familyContentView.subviews.filter({ !($0 === exceptSubview) })
    subviewsInLayoutOrder = filteredSubviews
  }

  private func validateView(_ view: NSView) -> Bool {
    return view.isHidden == false && view.alphaValue > CGFloat(0.0)
  }

  @objc func injected() {
    runLayoutSubviewsAlgorithm()
  }

  private func runLayoutSubviewsAlgorithm(useBinarySearch: Bool = false) {
    var yOffsetOfCurrentSubview: CGFloat = 0.0
    let result: [NSView]
    if useBinarySearch {
      guard let results: [NSView] = binarySearch.findElements(in: subviewsInLayoutOrder,
                                                              less: { documentVisibleRect.maxY > $0.frame.minY },
                                                              match: { documentVisibleRect.intersects($0.frame) }) else { return }
      result = results
    } else {
      result = subviewsInLayoutOrder
    }

    for view in result where validateView(view) {
      var frame = view.frame
      frame.size.width = self.frame.size.width
      frame.size.height = contentSizeForView(view).height
      frame.origin.y = yOffsetOfCurrentSubview
      view.frame = frame
      yOffsetOfCurrentSubview += frame.height + spaceManager.customSpacing(after: view)
    }
  }

  private func contentSizeForView(_ view: NSView) -> CGSize {
    var contentSize: CGSize = .zero
    switch view {
    case let collectionView as NSCollectionView:
      if let flowLayout = collectionView.collectionViewLayout as? NSCollectionViewFlowLayout {
        flowLayout.invalidateLayout()
        contentSize = flowLayout.collectionViewContentSize
      }
    default:
      contentSize = view.frame.size
    }

    return contentSize
  }

  private func computeContentSize() {
    let computedHeight: CGFloat = subviewsInLayoutOrder
      .filter({ validateView($0) })
      .reduce(0, { $0 + ($1.frame.size.height) + spaceManager.customSpacing(after: $1) })
    let minimumContentHeight = bounds.height
    var height = fmax(computedHeight, minimumContentHeight)

    if computedHeight < minimumContentHeight {
      height -= contentInsets.top
    }

    documentView?.frame.size = CGSize(width: bounds.size.width, height: height)
  }
}
