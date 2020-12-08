import Cocoa

class FamilyWrapperView: NSScrollView, ViewWrapper {
  override var isFlipped: Bool { return true }
  weak var parentDocumentView: FamilyDocumentView?
  var isScrolling: Bool = false
  var view: NSView
  private lazy var clipView = FamilyClipView()
  private var frameObserver: NSKeyValueObservation?
  private var alphaObserver: NSKeyValueObservation?
  private var hiddenObserver: NSKeyValueObservation?
  private var familyScrollView: FamilyScrollView? { return enclosingScrollView as? FamilyScrollView }

  open override var verticalScroller: NSScroller? {
    get { return nil }
    set {}
  }

  required init(frame frameRect: NSRect, wrappedView: NSView) {
    self.view = wrappedView
    super.init(frame: frameRect)
    // Disable resizing of subviews to avoid recursion.
    // The wrapper view should follow the `.view`'s size, not the
    // otherway around. If this is set to `true` then there is
    // a potential for the observers trigger a resizing recursion.
    self.autoresizesSubviews = false
    self.contentView = clipView
    self.documentView = wrappedView
    self.hasVerticalScroller = false
    self.postsBoundsChangedNotifications = true
    self.verticalScrollElasticity = .none
    self.drawsBackground = false

    self.frameObserver = view.observe(\.frame, options: [.initial, .new, .old], changeHandler: { [weak self] (_, value) in
      guard let newValue = value.newValue else { return }

      if let collectionView = wrappedView as? NSCollectionView,
        let layout = collectionView.collectionViewLayout {
        guard newValue != value.oldValue || layout.collectionViewContentSize != newValue.size else { return }
      } else {
        guard newValue != value.oldValue else { return }
      }

      self?.setWrapperFrameSize(newValue)
      self?.invalidateFamilyScrollView(needsDisplay: false)
    })

    self.alphaObserver = view.observe(\.alphaValue, options: [.new, .old]) { [weak self] (_, value) in
      guard value.newValue != value.oldValue,
        let newValue = value.newValue,
        let oldValue = value.oldValue else { return }

      self?.alphaValue = newValue

      let shouldInvalidate = oldValue == 0 || newValue == 0
      guard shouldInvalidate else { return }
      self?.invalidateFamilyScrollView(needsDisplay: false)
    }

    self.hiddenObserver = view.observe(\.isHidden, options: [.new, .old]) { [weak self] (_, value) in
      guard value.newValue != value.oldValue, let newValue = value.newValue else { return }
      self?.isHidden = newValue
      self?.invalidateFamilyScrollView(needsDisplay: true)
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

  private func invalidateFamilyScrollView(needsDisplay: Bool) {
    guard let familyScrollView = familyScrollView else { return }
    guard familyScrollView.isPerformingBatchUpdates == false else { return }

    if familyScrollView.cache.state != .isRunning {
      familyScrollView.cache.invalidate()
      familyScrollView.layoutViews(withDuration: nil,
                                   allowsImplicitAnimation: false,
                                   force: true,
                                   completion: nil)
      guard needsDisplay else { return }
      familyScrollView.setNeedsDisplay(frame)
      familyScrollView.layoutSubtreeIfNeeded()
    }
  }

  private func setWrapperFrameSize(_ rect: CGRect) {
    let oldValue = frame
    let newValue = rect

    frame.size.height = newValue.size.height
    familyScrollView?.wrapperViewDidChangeFrame(view, from: oldValue, to: newValue)
  }
}
