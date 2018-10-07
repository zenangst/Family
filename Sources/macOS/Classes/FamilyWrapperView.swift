import Cocoa

class FamilyWrapperView: NSScrollView {
  weak var parentContentView: FamilyContentView?
  var isScrolling: Bool = false
  var view: NSView
  private var frameObserver: NSKeyValueObservation?
  private var alphaObserver: NSKeyValueObservation?
  private var hiddenObserver: NSKeyValueObservation?

  open override var verticalScroller: NSScroller? {
    get { return nil }
    set {}
  }

  required init(frame frameRect: NSRect, wrappedView: NSView) {
    self.view = wrappedView
    super.init(frame: frameRect)
    self.contentView = NSClipView()
    self.contentView.translatesAutoresizingMaskIntoConstraints = false
    self.documentView = wrappedView
    self.hasHorizontalScroller = true
    self.hasVerticalScroller = false
    self.postsBoundsChangedNotifications = true
    self.verticalScrollElasticity = .none

    self.frameObserver = wrappedView.observe(\.frame, options: [.new, .old], changeHandler: { [weak self] (_, value) in
      guard value.newValue != value.oldValue else { return }
      self?.layoutViews(force: true)
    })

    self.alphaObserver = view.observe(\.alphaValue, options: [.initial, .new, .old]) { [weak self] (_, value) in
      guard value.newValue != value.oldValue, let newValue = value.newValue else { return }
      self?.alphaValue = newValue
      self?.layoutViews()
    }

    self.hiddenObserver = view.observe(\.isHidden, options: [.initial, .new, .old]) { [weak self] (_, value) in
      guard value.newValue != value.oldValue, let newValue = value.newValue else { return }
      self?.isHidden = newValue
      self?.layoutViews()
    }
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func scrollWheel(with event: NSEvent) {
    if event.scrollingDeltaX != 0.0 && view.frame.size.width > frame.size.width {
      super.scrollWheel(with: event)
    } else if event.scrollingDeltaY != 0.0 {
      nextResponder?.scrollWheel(with: event)
    }

    isScrolling = !(event.deltaX == 0 && event.deltaY == 0) ||
      !(event.phase == .ended || event.momentumPhase == .ended)
  }

  func layoutViews(force: Bool = false) {
    if force {
      (enclosingScrollView as? FamilyScrollView)?.wrapperViewDidChangeFrame()
      return
    }

    guard window?.inLiveResize != true,
      !isScrolling,
      let familyScrollView = parentContentView?.familyScrollView else {
        return
    }

    if NSAnimationContext.current.duration > 0.0 && !familyScrollView.layoutIsRunning {
      if view is NSCollectionView {
        let delay = NSAnimationContext.current.duration
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
          familyScrollView.layoutViews(withDuration: 0.0)
        }
      } else {
        familyScrollView.layoutViews(withDuration: NSAnimationContext.current.duration)
      }
    } else {
      (enclosingScrollView as? FamilyScrollView)?.layoutViews()
    }
  }
}
