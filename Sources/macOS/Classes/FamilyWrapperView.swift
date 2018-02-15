import Cocoa

class FamilyClipView: NSClipView {
  override func scroll(_ point: NSPoint) {
    enclosingScrollView?.documentView?.scroll(point)
  }
}

class FamilyWrapperView: NSScrollView {
  var containerView: NSView = .init()
  var view: NSView
  var observer: NSKeyValueObservation?

  required init(frame frameRect: NSRect, documentView: NSView) {
    self.view = documentView
    super.init(frame: frameRect)
    self.contentView = FamilyClipView()
    self.documentView = containerView
    self.containerView.addSubview(view)
    self.observer = view.observe(\.frame, options: [.initial, .new, .old]) { [weak self] _, value in
      if value.newValue != value.oldValue, let rect = value.newValue {
        self?.setWrapperFrameSize(rect)
      }
    }
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func scrollWheel(with event: NSEvent) {
    if event.scrollingDeltaX != 0.0 {
      super.scrollWheel(with: event)
    } else if event.scrollingDeltaY != 0.0 {
      nextResponder?.scrollWheel(with: event)
    }
  }

  private func setWrapperFrameSize(_ rect: CGRect) {
    if rect.size != documentView?.frame.size {
      documentView?.frame.size = rect.size
    }
  }
}
