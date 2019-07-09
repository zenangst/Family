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
    eventHandlerKeyDown = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event -> NSEvent? in
      self?.scrollView.isScrollingByProxy = true
      return event
    }
  }

  open override func viewDidLayout() {
    super.viewDidLayout()

    if isChildViewController {
      scrollView.frame = view.bounds
      view.frame.size.height = scrollView.contentSize.height
    }
  }

  // MARK: - Public methods

  public func body(withDuration duration: Double = 0.25,
                   _ closure: () -> Void) {
    performBatchUpdates(withDuration: duration, { _ in
      closure()
    }, completion: { _ in })
  }

  @discardableResult
  public func add<T: ViewController>(_ childController: T, view handler: ((T) -> View)? = nil) -> T {
    addChild(childController, view: handler)
    return childController
  }

  @discardableResult
  public func addBackground<T: ViewController>(_ kind: BackgroundKind, to viewController: T) -> T {
    guard let view = registry[viewController] else {
      assertionFailure("Unable to find view controller \(type(of: viewController.self))")
      return viewController
    }

    if let wrapperView = view.superview as? FamilyClipView {
      switch kind {
      case .color(let newColor):
        wrapperView.backgroundColor = newColor
      case .view(let backgroundView):
        scrollView.addBackground(backgroundView, to: view)
      }
    } else if let collectionView = view as? NSCollectionView {
      switch kind {
      case .color(let newColor):
        collectionView.backgroundColors = [newColor]
      case .view(let backgroundView):
        collectionView.backgroundColors = [NSColor.clear]
        scrollView.addBackground(backgroundView, to: view)
      }
    } else {
      switch kind {
      case .color(let newColor):
        view.wantsLayer = true
        view.layer?.backgroundColor = newColor.cgColor
      case .view(let backgroundView):
        scrollView.addBackground(backgroundView, to: view)
      }
    }

    return viewController
  }

  @discardableResult func addPadding<T: ViewController>(_ insets: Insets, to viewController: T) -> T {
    guard let view = registry[viewController] else {
      assertionFailure("Cannot set padding to \(type(of: T.self)) because it has no superview.")
      return viewController
    }

    scrollView.addPadding(insets, for: view)

    return viewController
  }

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
  @discardableResult
  public func addChild<T: ViewController>(_ childController: T,
                                          at index: Int? = nil,
                                          insets: Insets? = nil,
                                          height: CGFloat? = nil,
                                          view handler: ((T) -> View)? = nil) -> Self {
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
    addView(subview, at: index, insets: insets, height: height)
    registry[childController] = subview
    scrollView.purgeWrapperViews()

    return self
  }

  /// Adds a collection of view controllers as children of the current view controller.
  ///
  /// - Parameter childControllers: The view controllers to be added as children.
  @discardableResult
  public func addChildren(_ childControllers: NSViewController ...) -> Self {
    return addChildren(childControllers)
  }

  /// Adds a collection of view controllers as children of the current view controller.
  ///
  /// - Parameter childControllers: The view controllers to be added as children.
  @discardableResult
  public func addChildren(_ childControllers: [NSViewController]) -> Self {
    for childController in childControllers {
      addChild(childController)
    }
    return self
  }

  /// Add a new view to hierarchy.
  ///
  /// - Parameters:
  ///   - subview: The view that should be added.
  ///   - index: The index that the view should appear.
  ///   - height: An optional height of the view.
  ///   - insets: The insets that should be applied to the view.
  @discardableResult
  public func addView(_ subview: View,
                      at index: Int? = nil,
                      insets: Insets? = nil,
                      height: CGFloat? = nil) -> Self {
    if let height = height {
      subview.frame.size.width = view.bounds.size.width
      subview.frame.size.height = height
    } else {
      subview.frame.size.width = view.bounds.width
    }
    addOrInsertView(subview, at: index)
    scrollView.frame = view.bounds

    if let insets = insets {
      addMargins(insets, for: subview)
    }

    return self
  }

  /// Move child view controller to index.
  ///
  /// - Parameters:
  ///   - childController: The child view controller that should be moved to index.
  ///   - index: The new index of the child view controller.
  @discardableResult
  open func moveChild(_ childController: ViewController, to index: Int) -> Self {
    guard let view = registry[childController] else { return self }
    addOrInsertView(view, at: index)
    return self
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
    return scrollView.margins(for: view)
  }

  /// Get margins for a specific view.
  ///
  /// - Parameter view: The target view which is used to lookup insets.
  /// - Returns: The insets for the view, it defaults to the scroll views
  ///            generic insets.
  public func margins(for view: View) -> Insets {
    return scrollView.margins(for: view)
  }

  /// Set margins to a view.
  ///
  /// - Parameters:
  ///   - insets: The custom insets for the view.
  ///   - view: The target view that should get custom insets.
  public func addMargins(_ insets: Insets, for view: View) {
    scrollView.addMargins(insets, for: view)
  }

  /// Get padding for a specific view.
  ///
  /// - Parameter view: The target view which is used to lookup insets.
  /// - Returns: The insets for the view, it defaults to the scroll views
  ///            generic insets.
  public func padding(for view: View) -> Insets {
    return scrollView.padding(for: view)
  }

  /// Set padding to a view.
  ///
  /// - Parameters:
  ///   - insets: The custom insets for the view.
  ///   - view: The target view that should get custom insets.
  public func addPadding(_ insets: Insets, for view: View) {
    scrollView.addPadding(insets, for: view)
  }

  /// Animates view hierarchy operations as a group.
  /// This guards the layout algorithm from being invoked multiple
  /// times while mutating the view hierarchy.
  ///
  /// - Parameters:
  ///   - handler: The operations that should be performed as a group.
  ///   - completion: A completion handler that is invoked after the view
  ///                 has laid out its views.
  @discardableResult
  public func performBatchUpdates(withDuration duration: Double = 0.0,
                                  _ handler: (FamilyViewController) -> Void,
                                  completion: ((FamilyViewController) -> Void)?) -> Self {
    scrollView.isPerformingBatchUpdates = true
    handler(self)
    scrollView.isPerformingBatchUpdates = false
    scrollView.layoutViews(withDuration: duration, force: false) {
      completion?(self)
    }
    return self
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
  @discardableResult
  func purgeRemovedViews() -> Self {
    for (controller, view) in registry where controller.parent == nil {
      view.enclosingScrollView?.removeFromSuperview()
      registry.removeValue(forKey: controller)
    }
    return self
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
