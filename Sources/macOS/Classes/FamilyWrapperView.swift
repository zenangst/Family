import Cocoa

class FamilyWrapperView: NSScrollView {
  var wrappedView: NSView
  var observer: NSKeyValueObservation?
  var animationsObserver: NSKeyValueObservation?
  var viewContentSize: CGSize = .zero

  open override var verticalScroller: NSScroller? {
    get { return nil }
    set {}
  }

  required init(frame frameRect: NSRect, wrappedView: NSView) {
    self.wrappedView = wrappedView
    super.init(frame: frameRect)
    self.contentView = NSClipView()
    self.documentView = wrappedView
    self.hasHorizontalScroller = true
    self.hasVerticalScroller = false

    self.observer = wrappedView.observe(\.frame, options: [.initial, .new, .old]) { [weak self] view, value in
      if value.newValue != value.oldValue, let rect = value.newValue {
        self?.notifyFamilyScrollView()
      }
    }
  }

  func notifyFamilyScrollView() {
    if let familyScrollView = enclosingScrollView as? FamilyScrollView {
      familyScrollView.layoutViews()
    }
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func scrollWheel(with event: NSEvent) {
    if event.scrollingDeltaX != 0.0 && wrappedView.frame.size.width > frame.size.width {
      super.scrollWheel(with: event)
    } else if event.scrollingDeltaY != 0.0 {
      nextResponder?.scrollWheel(with: event)
    }
  }
}
