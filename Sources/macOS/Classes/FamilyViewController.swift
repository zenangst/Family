import Cocoa

open class FamilyViewController: NSViewController, FamilyFriendly {

  public lazy var baseView = NSView()
  public lazy var scrollView: FamilyScrollView = .init()
  /// The scroll view constraints.
  public var constraints = [NSLayoutConstraint]()

  //  The current viewport of the scroll view
  public var documentVisibleRect: CGRect { return scrollView.documentVisibleRect }
  public var isChildViewController: Bool = false {
    didSet {
      scrollView.isChildViewController = isChildViewController
      scrollView.isScrollEnabled = !isChildViewController
    }
  }

  private(set) public var registry = [ViewController: View]()
  var observer: NSKeyValueObservation?
  var eventHandlerKeyDown: Any?

  public convenience init(isChildViewController: Bool) {
    self.init(nibName: nil, bundle: nil)
    self.isChildViewController = isChildViewController
  }

  public override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
    super.init(nibName: nil, bundle: nil)
  }

  public required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  deinit {
    scrollView.isDeallocating = true
    children.forEach { $0.removeFromParent() }
    purgeRemovedViews()

    if let eventHandlerKeyDown = eventHandlerKeyDown { NSEvent.removeMonitor(eventHandlerKeyDown) }
  }

  // MARK: - View lifecycle

  open override func loadView() {
    let view = baseView
    view.autoresizingMask = [.width]
    view.autoresizesSubviews = true
    self.view = view
    observer = observe(\.children, options: [.new, .old], changeHandler: { controller, _ in
      controller.purgeRemovedViews()
    })
  }

  /// Called after the controller's view is loaded into memory.
  open override func viewDidLoad() {
    super.viewDidLoad()
    view.addSubview(scrollView)
    scrollView.autoresizingMask = [.width]
    if !isChildViewController {
      configureConstraints()
    } else {
      scrollView.isScrollEnabled = false
      scrollView.frame = view.bounds
    }
    eventHandlerKeyDown = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { (event) -> NSEvent? in
      self.scrollView.isScrollingByProxy = true
      return event
    }
  }

  open override func viewDidAppear() {
    super.viewDidAppear()
    // Make sure that we do another layout pass when the view controller appears.
    // It helps ensure that we get the correct sizes on the subviews inside the `FamilyScrollView`.
    NotificationCenter.default.post(Notification.init(name: NSWindow.didResizeNotification))
  }

  open override func viewDidLayout() {
    super.viewDidLayout()

    if isChildViewController {
      scrollView.frame = view.bounds
      view.frame.size.height = scrollView.contentSize.height
    }
  }

  // MARK: - Public methods

  /// Adds the specified view controller as a child of the current view controller.
  ///
  /// - Parameter childController: The view controller to be added as a child.
  open override func addChild(_ childController: ViewController) {
    super.addChild(childController)
    childController.view.frame.size.width = view.bounds.width
    addOrInsertView(childController.view)
    scrollView.frame = view.bounds
    registry[childController] = childController.view
  }

  /// Adds the specified view controller as a child of the current view controller.
  /// The view handler is used to resolve another view for the view controller that should
  /// be added into the view heirarcy.
  ///
  /// - Parameters:
  ///   - childController: The view controller to be added as a child.
  ///   - index: The index that the view should appear in the view hierarchy.
  ///   - customInsets: The insets that should be applied to the view.
  ///   - height: The height that the child controllers should be constrained to.
  ///   - handler: A closure used to resolve a view other than `.view` on controller used
  ///              to render the view controller.
  public func addChild<T: ViewController>(_ childController: T,
                                          at index: Int? = nil,
                                          customInsets insets: Insets? = nil,
                                          height: CGFloat? = nil,
                                          view handler: ((T) -> View)? = nil) {
    super.addChild(childController)

    let subview: View

    if let handler = handler {
      view.addSubview(childController.view)
      childController.view.frame.size = .zero
      subview = handler(childController)
    } else {
      subview = childController.view
    }

    scrollView.frame = view.bounds
    subview.frame.size.width = view.bounds.width
    addView(subview, at: index, customInsets: insets, withHeight: height)
    registry[childController] = subview
    scrollView.purgeWrapperViews()
  }

  /// Adds a collection of view controllers as children of the current view controller.
  ///
  /// - Parameter childControllers: The view controllers to be added as children.
  public func addChildren(_ childControllers: NSViewController ...) {
    addChildren(childControllers)
  }

  /// Adds a collection of view controllers as children of the current view controller.
  ///
  /// - Parameter childControllers: The view controllers to be added as children.
  public func addChildren(_ childControllers: [NSViewController]) {
    for childController in childControllers {
      addChild(childController)
    }
  }

  /// Add a new view to hierarchy.
  ///
  /// - Parameters:
  ///   - subview: The view that should be added.
  ///   - index: The index that the view should appear.
  ///   - height: An optional height of the view.
  ///   - insets: The insets that should be applied to the view.
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

  /// Move child view controller to index.
  ///
  /// - Parameters:
  ///   - childController: The child view controller that should be moved to index.
  ///   - index: The new index of the child view controller.
  open func moveChild(_ childController: ViewController, to index: Int) {
    guard let view = registry[childController] else { return }
    addOrInsertView(view, at: index)
  }

  /// Returns a collection of view controllers in layout order.
  /// It uses the order as they appear in the document view on the scroll view
  /// to give a true representation of how the views appear on screen.
  ///
  /// - Returns: A collection of view controllers.
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

  /// Get custom insets for a specific view.
  ///
  /// - Parameter view: The target view which is used to lookup insets.
  /// - Returns: The insets for the view, it defaults to the scroll views
  ///            generic insets.
  public func customInsets(for view: View) -> Insets {
    return scrollView.customInsets(for: view)
  }

  /// Set custom insets to a view.
  ///
  /// - Parameters:
  ///   - insets: The custom insets for the view.
  ///   - view: The target view that should get custom insets.
  public func setCustomInsets(_ insets: Insets, for view: View) {
    scrollView.setCustomInsets(insets, for: view)
  }

  /// Animates view hierarchy operations as a group.
  /// This guards the layout algorithm from being invoked multiple
  /// times while mutating the view hierarchy.
  ///
  /// - Parameters:
  ///   - handler: The operations that should be performed as a group.
  ///   - completion: A completion handler that is invoked after the view
  ///                 has laid out its views.
  public func performBatchUpdates(_ handler: (FamilyViewController) -> Void,
                                  completion: ((FamilyViewController) -> Void)?) {
    scrollView.isPerformingBatchUpdates = true
    handler(self)
    scrollView.isPerformingBatchUpdates = false
    scrollView.layoutViews(withDuration: 0.25) {
      completion?(self)
    }
  }

  /// Check if a view controller is visible on screen.
  ///
  /// - Parameter viewController: The target view controller
  /// - Returns: True if the view controller is visible on screen
  public func viewControllerIsVisible(_ viewController: NSViewController) -> Bool {
    guard let entry = registry[viewController] else { return false }
    let view = wrappedViewIfNeeded(entry)
    if view.frame.size.height == 0 { return false }
    return view.frame.intersects(documentVisibleRect)
  }

  /// Check if a view controller is fully visible on screen.
  ///
  /// - Parameter viewController: The target view controller
  /// - Returns: True if the view controller is fully visible on screen
  public func viewControllerIsFullyVisible(_ viewController: NSViewController) -> Bool {
    guard let entry = registry[viewController] else { return false }
    let view = wrappedViewIfNeeded(entry)
    if view.frame.size.height == 0 { return false }
    let convertedFrame = scrollView.familyDocumentView.convert(view.frame,
                                                         to: scrollView.documentView)
    return documentVisibleRect.contains(convertedFrame)
  }

  /// Extract attributes for a view controller.
  ///
  /// - Parameter viewController: The target view controller.
  /// - Returns: An optional `FamilyViewControllerAttributes` for the target view controller.
  public func attributesForViewController(_ viewController: NSViewController) -> FamilyViewControllerAttributes? {
    guard let view = registry[viewController],
      let attributes = scrollView.cache.entry(for: view) else { return nil }
    return attributes
  }

  /// Remove stray views from view hierarchy.
  func purgeRemovedViews() {
    for (controller, view) in registry where controller.parent == nil {
      view.enclosingScrollView?.removeFromSuperview()
      registry.removeValue(forKey: controller)
    }
  }

  // MARK: - Private methods

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

  public func wrappedViewIfNeeded(_ view: NSView) -> NSView {
    if let wrapperView = view.enclosingScrollView as? FamilyWrapperView {
      return wrapperView
    }

    return view
  }

  /// Appends or inserts a view at a specific index.
  ///
  /// - Parameters:
  ///   - view: The view that should be added or inserted depending
  ///           on if an index is provided.
  ///   - index: An optional index for where the view should appear.
  private func addOrInsertView(_ view: View, at index: Int? = nil) {
    if let index = index, index < scrollView.familyDocumentView.subviewsInLayoutOrder.count {
      scrollView.familyDocumentView.insertSubview(view, at: index)
    } else {
      scrollView.familyDocumentView.addSubview(view)
    }
  }
}
