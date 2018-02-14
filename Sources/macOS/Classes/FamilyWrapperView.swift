import Cocoa

class FamilyClipView: NSClipView {
  override func scroll(_ point: NSPoint) {
    enclosingScrollView?.documentView?.scroll(point)
  }
}

class FamilyWrapperView: NSScrollView {
  required init(frame frameRect: NSRect, documentView: NSView) {
    super.init(frame: frameRect)
    self.contentView = FamilyClipView()
    self.documentView = documentView
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
}
