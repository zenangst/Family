import Cocoa

public class FamilyScrollView: NSScrollView {
  public lazy var familyContentView: FamilyContentView = .init()
  public var spacingBetweenViews: CGFloat = 0
  private var observers = [Observer]()
  private var subviewsInLayoutOrder = [NSScrollView]()

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

    NotificationCenter.default.addObserver(self, selector: #selector(contentViewBoundsDidChange(_:)),
                                           name: NSView.boundsDidChangeNotification,
                                           object: contentView)
    contentView.postsBoundsChangedNotifications = true
  }

  required public init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
    subviewsInLayoutOrder.removeAll()
    observers.removeAll()
  }

  @objc func contentViewBoundsDidChange(_ notification: NSNotification) {
    guard (notification.object as? NSClipView) === contentView else {
      return
    }

    guard let window = window, !window.inLiveResize else {
      return
    }

    layoutViews()
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

  public func layoutViews(withDuration duration: CFTimeInterval? = nil) {
    runLayoutSubviewsAlgorithm()
    computeContentSize()
  }

  private func computeContentSize() {
    let computedHeight = subviewsInLayoutOrder.reduce(0, { $0 + $1.contentSize.height + spacingBetweenViews })
    let minimumContentHeight = bounds.height
    let height = fmax(computedHeight, minimumContentHeight)
    documentView?.frame.size = CGSize(width: bounds.size.width, height: height)
  }

  private func runLayoutSubviewsAlgorithm() {
    var yOffsetOfCurrentSubview: CGFloat = 0.0

    for scrollView in subviewsInLayoutOrder {
      guard let documentView: View = scrollView.documentView else {
        return
      }

      var contentSize: CGSize = documentView.frame.size
      var shouldResize: Bool = true
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
      var shouldScroll: Bool = true
      frame.size.height = round(newHeight)
      frame.size.width = round(self.frame.size.width)

      scrollView.documentView?.frame.size.width = self.frame.width
      scrollView.documentView?.frame.size.height = contentSize.height
      scrollView.frame = frame

      if shouldScroll {
        (scrollView.contentView as? NSClipView)?.scroll(contentOffset)
      }

      yOffsetOfCurrentSubview += contentSize.height
    }

    guard frame.height > 0 && frame.width > 100 else {
      return
    }

    if frame.origin.y < 0 {
      yOffsetOfCurrentSubview -= frame.origin.y
    }
  }
}
