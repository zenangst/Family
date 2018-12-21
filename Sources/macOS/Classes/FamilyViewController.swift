import Cocoa

open class FamilyViewController: NSViewController, FamilyFriendly {

  public lazy var baseView = NSView()
  public lazy var scrollView: FamilyScrollView = .init()
  /// The scroll view constraints.
  public var constraints = [NSLayoutConstraint]()
  private(set) public var registry = [ViewController: View]()
  var observer: NSKeyValueObservation?
  var eventHandlerKeyDown: Any?

  deinit {
    children.forEach { $0.removeFromParent() }
    purgeRemovedViews()

    if let eventHandlerKeyDown = eventHandlerKeyDown { NSEvent.removeMonitor(eventHandlerKeyDown) }
  }

  open override func loadView() {
    let view = baseView
    view.autoresizingMask = [.width]
    view.autoresizesSubviews = true
    self.view = view
    observer = observe(\.children, options: [.new, .old], changeHandler: { controller, _ in
      controller.purgeRemovedViews()
    })
  }

  open override func viewDidLoad() {
    super.viewDidLoad()
    view.addSubview(scrollView)
    scrollView.autoresizingMask = [.width]
    configureConstraints()
    eventHandlerKeyDown = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { (event) -> NSEvent? in
      self.scrollView.isScrollingByProxy = true
      return event
    }
  }

  private func configureConstraints() {
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    if #available(OSX 10.11, *) {
      NSLayoutConstraint.deactivate(constraints)
      constraints.removeAll()
      constraints.append(contentsOf: [
        scrollView.topAnchor.constraint(equalTo: view.topAnchor),
        scrollView.leftAnchor.constraint(equalTo: view.leftAnchor),
        scrollView.rightAnchor.constraint(equalTo: view.rightAnchor),
        scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
      ])
      NSLayoutConstraint.activate(constraints)
    }
  }

  open override func addChild(_ childController: ViewController) {
    super.addChild(childController)
    childController.view.frame.size.width = view.bounds.width
    addOrInsertView(childController.view)
    scrollView.frame = view.bounds
    registry[childController] = childController.view
  }

  public func addChild(_ childController: ViewController,
                       at index: Int? = nil) {
    super.addChild(childController)
    childController.view.frame.size.width = view.bounds.width
    addOrInsertView(childController.view, at: index)
    scrollView.frame = view.bounds
    registry[childController] = childController.view
  }

  public func addChild(_ childController: ViewController,
                       at index: Int? = nil,
                       customInsets insets: Insets? = nil,
                       height: CGFloat) {
    super.addChild(childController)
    childController.view.frame.size.width = view.bounds.width
    addOrInsertView(childController.view, at: index)
    scrollView.frame = view.bounds
    registry[childController] = childController.view
    childController.view.frame.size.height = height
    childController.view.frame.size.width = view.bounds.width
    scrollView.frame = view.bounds

    if let insets = insets {
      setCustomInsets(insets, for: childController.view)
    }
  }

  public func addChild<T: ViewController>(_ childController: T,
                                          at index: Int? = nil,
                                          customInsets insets: Insets? = nil,
                                          view closure: (T) -> View) {
    super.addChild(childController)
    view.addSubview(childController.view)
    childController.view.frame.size = .zero
    let childView = closure(childController)
    addView(childView, at: index, customInsets: insets)
    registry[childController] = childView
  }

  public func addChildren(_ childControllers: NSViewController ...) {
    addChildren(childControllers)
  }

  public func addChildren(_ childControllers: [NSViewController]) {
    for childController in childControllers {
      addChild(childController)
    }
  }

  public func addView(_ subview: View,
                      at index: Int? = nil,
                      customInsets insets: Insets? = nil,
                      withHeight height: CGFloat? = nil) {
    if let height = height {
      subview.frame.size.width = view.bounds.size.width
      subview.frame.size.height = height
    } else {
      subview.frame.size.width = view.bounds.width
    }
    addOrInsertView(subview, at: index)
    scrollView.frame = view.bounds

    if let insets = insets {
      setCustomInsets(insets, for: subview)
    }
  }

  public func viewControllersInLayoutOrder() -> [ViewController] {
    var viewControllers = [ViewController]()
    var temporaryContainer = [View: ViewController]()

    for entry in registry {
      temporaryContainer[entry.value] = entry.key
    }

    for view in scrollView.familyDocumentView.subviewsInLayoutOrder {
      let lookupView = (view as? FamilyWrapperView)?.view ?? view
      guard let controller = temporaryContainer[lookupView] else { continue }
      viewControllers.append(controller)
    }

    return viewControllers
  }

  public func customInsets(for view: View) -> Insets {
    return scrollView.customInsets(for: view)
  }

  public func setCustomInsets(_ insets: Insets, for view: View) {
    scrollView.setCustomInsets(insets, for: view)
  }

  func performBatchUpdates(_ handler: (FamilyViewController) -> Void, completion: ((FamilyViewController) -> Void)?) {
    scrollView.isPerformingBatchUpdates = true
    handler(self)
    scrollView.isPerformingBatchUpdates = false
    scrollView.layoutViews(withDuration: 0.25)
    completion?(self)
  }

  private func addOrInsertView(_ view: View, at index: Int? = nil) {
    if let index = index, index < scrollView.familyDocumentView.subviewsInLayoutOrder.count {
      scrollView.familyDocumentView.insertSubview(view, at: index)
    } else {
      scrollView.familyDocumentView.addSubview(view)
    }
  }

  func purgeRemovedViews() {
    for (controller, view) in registry where controller.parent == nil {
      view.enclosingScrollView?.removeFromSuperview()
      registry.removeValue(forKey: controller)
    }
  }
}
