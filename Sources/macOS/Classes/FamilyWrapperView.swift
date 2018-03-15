import Cocoa

class FamilyWrapperView: NSScrollView {
  var isScrolling: Bool = false
  var view: NSView
  private var observer: NSKeyValueObservation?

  open override var verticalScroller: NSScroller? {
    get { return nil }
    set {}
  }

  required init(frame frameRect: NSRect, wrappedView: NSView) {
    self.view = wrappedView
    super.init(frame: frameRect)
    self.contentView = NSClipView()
    self.documentView = wrappedView
    self.hasHorizontalScroller = true
    self.hasVerticalScroller = false
    self.postsBoundsChangedNotifications = true
    self.verticalScrollElasticity = .none

    self.observer = wrappedView.observe(\.frame, options: [.new, .old], changeHandler: { (_, value) in
      if value.newValue != value.oldValue {
        self.layoutViews()
      }
    })
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func layout() {
    super.layout()
    layoutViews()
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

  func layoutViews() {
    guard window?.inLiveResize != true,
      !isScrolling,
      let familyScrollView = enclosingScrollView as? FamilyScrollView else {
        return
    }

    if NSAnimationContext.current.duration > 0.0 && !familyScrollView.layoutIsRunning {
      if view is NSCollectionView {
        let delay = NSAnimationContext.current.duration
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
          familyScrollView.layoutViews(withDuration: delay)
        }
      } else {
        familyScrollView.layoutViews(withDuration: NSAnimationContext.current.duration)
      }
    } else {
      (enclosingScrollView as? FamilyScrollView)?.layoutViews()
    }
  }
}
