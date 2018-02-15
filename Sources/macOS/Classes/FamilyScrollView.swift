import Cocoa

public class FamilyScrollView: NSScrollView {
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

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(contentViewBoundsDidChange(_:)),
      name: NSView.boundsDidChangeNotification,
      object: contentView
    )

    contentView.postsBoundsChangedNotifications = true
    familyContentView.autoresizingMask = [.width]
  }

  required public init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
    subviewsInLayoutOrder.removeAll()
    observers.removeAll()
  }

  // MARK: - Observers

  @objc func didLiveScroll(_ notification: NSNotification) {}

  @objc func contentViewBoundsDidChange(_ notification: NSNotification) {
    guard (notification.object as? NSClipView) === contentView else {
      return
    }

    guard let window = window, !window.inLiveResize else {
      return
    }
    layoutViews()
  }

  // MARK: - Public methods

  public func layoutViews(withDuration duration: CFTimeInterval? = nil) {
    runLayoutSubviewsAlgorithm()
    computeContentSize()
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

    observeView(view: scrollView)
  }

  public override func layout() {
    super.layout()
    layoutViews()
  }

  // MARK: - Private methods

  private func rebuildSubviewsInLayoutOrder(exceptSubview: View? = nil) {
    subviewsInLayoutOrder.removeAll()
    let filteredSubviews = familyContentView.scrollViews.filter({ !($0 === exceptSubview) })
    subviewsInLayoutOrder = filteredSubviews
  }

  private func observeView(view: NSScrollView) {
    guard view.superview == familyContentView else { return }

    let contentSizeObserver = view.observe(\.contentSize, options: [.initial, .new, .old], changeHandler: { [weak self] (scrollView, value) in
      guard let strongSelf = self,
        let newValue = value.newValue,
        let oldValue = value.oldValue else {
          return
      }

      if newValue != oldValue {
        strongSelf.computeContentSize()
        strongSelf.layoutViews()
      }
    })

    observers.append(Observer(view: view, keyValueObservation: contentSizeObserver))

    let boundsObserver = view.observe(\.bounds, options: [.new, .old], changeHandler: { [weak self] (_, value) in
      guard let newValue = value.newValue, let oldValue = value.oldValue else {
        return
      }

      if newValue.origin.y != oldValue.origin.y {
        self?.layoutViews()
      }
    })

    observers.append(Observer(view: view, keyValueObservation: boundsObserver))
  }

  private func computeContentSize() {
    let computedHeight = subviewsInLayoutOrder.reduce(0, { $0 + $1.documentView!.frame.size.height + spacingBetweenViews })
    let minimumContentHeight = bounds.height
    let height = fmax(computedHeight, minimumContentHeight)
    documentView?.frame.size = CGSize(width: bounds.size.width, height: height)
  }

  private func runLayoutSubviewsAlgorithm() {
    let multipleComponents = subviewsInLayoutOrder.count > 1
    var yOffsetOfCurrentSubview: CGFloat = 0.0

    for (offset, scrollView) in subviewsInLayoutOrder.enumerated() {
      guard let documentView: View = scrollView.documentView else {
        return
      }

      var contentSize: CGSize = documentView.frame.size
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

      switch multipleComponents {
      case true:
        let shouldModifyContentOffset = contentOffset.y - contentInsets.top <= scrollView.contentSize.height + (contentInsets.top * 2) ||
          self.contentOffset.y != frame.minY

        if shouldModifyContentOffset {
          scrollView.contentView.scroll(contentOffset)
        } else {
          frame.origin.y = yOffsetOfCurrentSubview
        }
      case false:
        newHeight = fmin(contentView.frame.height, scrollView.contentSize.height)
      }

      frame.size.height = round(newHeight)
      frame.size.width = round(self.frame.size.width)

      documentView.frame.size.width = self.frame.width
      documentView.frame.size.height = contentSize.height
      scrollView.frame = frame

      yOffsetOfCurrentSubview += contentSize.height + spacingBetweenViews
    }
  }
}
