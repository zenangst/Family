import UIKit

/// This class is a `UIViewController` that adds some convenience methods
/// when using child view controllers to render your UI. The convenience methods
/// invoke the approriate child view controller related methods in sequence and
/// adds the controllers view or custom view to view heirarcy inside the
/// content view of the `FamilyScrollView`.
open class FamilyViewController: UIViewController, FamilyFriendly {
  var registry = [ViewController: (view: View, observer: NSKeyValueObservation)]()

  /// A custom implementation of a `UIScrollView` that handles continious scrolling
  /// when using scroll views inside of scroll view.
  public lazy var scrollView: FamilyScrollView = FamilyScrollView()
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
  public var safeAreaLayoutConstraints: Bool = true {
    didSet { configureConstraints() }
  }

  public convenience init(isChildViewController: Bool) {
    self.init(nibName: nil, bundle: nil)
    self.isChildViewController = isChildViewController
  }

  public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
    super.init(nibName: nil, bundle: nil)
  }

  public required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  deinit {
    scrollView.isDeallocating = true
    children.forEach {
      $0.willMove(toParent: nil)
      $0.removeFromParent()
      $0.view.removeFromSuperview()
    }
    purgeRemovedViews()
  }

  // MARK: - View lifecycle

  /// Called after the controller's view is loaded into memory.
  open override func viewDidLoad() {
    super.viewDidLoad()

    view.addSubview(scrollView)
    scrollView.alwaysBounceVertical = true
    scrollView.clipsToBounds = true
    scrollView.isChildViewController = isChildViewController
    if !isChildViewController {
      configureConstraints()
    } else {
      scrollView.isScrollEnabled = false
      scrollView.frame = view.bounds
    }
  }

  /// Notifies the view controller that its view is about to be added to a view hierarchy.
  ///
  /// - Parameter animated: If true, the view is being added to the window using an animation.
  open override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    if let tabBarController = self.tabBarController, tabBarController.tabBar.isTranslucent {
      if #available(iOS 11.0, *) {} else {
        scrollView.contentInset.bottom = tabBarController.tabBar.frame.size.height
        scrollView.scrollIndicatorInsets.bottom = scrollView.contentInset.bottom
      }
    }

    if let navigationController = self.navigationController, navigationController.navigationBar.isTranslucent {
      scrollView.contentInset.top = navigationController.navigationBar.frame.size.height
      scrollView.scrollIndicatorInsets.top = scrollView.contentInset.top
    }
  }

  open override func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()

    if isChildViewController {
      scrollView.frame = view.bounds
      view.frame.size.height = scrollView.contentSize.height
    }
  }

  // MARK: - Public methods

  /// Adds the specified view controller as a child of the current view controller.
  ///
  /// - Parameter childController: The view controller to be added as a child.
  open override func addChild(_ childController: UIViewController) {
    if childController.parent != nil {
      childController.removeFromParent()
    }
    purgeRemovedViews()
    childController.willMove(toParent: self)
    super.addChild(childController)
    let newView = viewToAdd(from: childController)
    addOrInsertView(newView)
    childController.didMove(toParent: self)
    registry[childController] = (newView, observe(childController))
    scrollView.purgeWrapperViews()
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
  public func addChild<T: UIViewController>(_ childController: T,
                                            at index: Int? = nil,
                                            insets: Insets? = nil,
                                            height: CGFloat? = nil,
                                            view handler: ((T) -> UIView)? = nil) -> Self {
    if childController.parent != nil {
      childController.removeFromParent()
    }
    purgeRemovedViews()
    childController.willMove(toParent: self)
    super.addChild(childController)

    let subview: View

    if let handler = handler {
      view.addSubview(childController.view)
      childController.view.frame.size = .zero
      childController.view.isHidden = true
      subview = handler(childController)
    } else {
      subview = childController.view
      childController.view.translatesAutoresizingMaskIntoConstraints = true
      childController.view.autoresizingMask = [.flexibleWidth]
    }

    addView(subview, at: index, insets: insets, height: height)
    registry[childController] = (subview, observe(childController))
    scrollView.purgeWrapperViews()
    childController.didMove(toParent: self)
    return self
  }

  /// Adds a collection of view controllers as children of the current view controller.
  ///
  /// - Parameter childControllers: The view controllers to be added as children.
  @discardableResult
  public func addChildren(_ childControllers: UIViewController ...) -> Self {
    return addChildren(childControllers)
  }

  /// Adds a collection of view controllers as children of the current view controller.
  ///
  /// - Parameter childControllers: The view controllers to be added as children.
  @discardableResult
  public func addChildren(_ childControllers: [UIViewController]) -> Self {
    for childController in childControllers {
      _ = addChild(childController)
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
    var newWidth = view.bounds.size.width

    if let insets = insets {
      newWidth = newWidth - insets.left - insets.right
      setCustomInsets(insets, for: subview)
    }

    if let height = height {
      subview.frame.size.width = newWidth
      subview.frame.size.height = height
    } else {
      subview.frame.size.width = newWidth
    }

    addOrInsertView(subview, at: index)
    return self
  }

  /// Move child view controller to index.
  ///
  /// - Parameters:
  ///   - childController: The child view controller that should be moved to index.
  ///   - index: The new index of the child view controller.
  @discardableResult
  open func moveChild(_ childController: UIViewController, to index: Int) -> Self {
    guard let entry = registry[childController] else { return self }
    addOrInsertView(entry.view, at: index)
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
      temporaryContainer[entry.value.view] = entry.key
    }

    for view in scrollView.documentView.scrollViews {
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
  @discardableResult
  public func performBatchUpdates(_ handler: (FamilyViewController) -> Void,
                                  completion: ((FamilyViewController) -> Void)? = nil) -> Self {
    scrollView.isPerformingBatchUpdates = true
    handler(self)
    scrollView.isPerformingBatchUpdates = false
    scrollView.layoutViews(withDuration: 0.25) {
      completion?(self)
    }

    return self
  }

  /// Check if a view controller is visible on screen.
  ///
  /// - Parameter viewController: The target view controller
  /// - Returns: True if the view controller is visible on screen
  public func viewControllerIsVisible(_ viewController: UIViewController) -> Bool {
    guard let entry = registry[viewController] else { return false }
    let view = wrappedViewIfNeeded(entry.view)
    if view.frame.size.height == 0 { return false }
    return view.frame.intersects(documentVisibleRect)
  }

  /// Check if a view controller is fully visible on screen.
  ///
  /// - Parameter viewController: The target view controller
  /// - Returns: True if the view controller is fully visible on screen
  public func viewControllerIsFullyVisible(_ viewController: UIViewController) -> Bool {
    guard let entry = registry[viewController] else { return false }
    let view = wrappedViewIfNeeded(entry.view)
    if view.frame.size.height == 0 { return false }
    let convertedFrame = scrollView.documentView.convert(view.frame,
                                                         to: scrollView.documentView)
    return documentVisibleRect.contains(convertedFrame)
  }

  /// Extract attributes for a view controller.
  ///
  /// - Parameter viewController: The target view controller.
  /// - Returns: An optional `FamilyViewControllerAttributes` for the target view controller.
  public func attributesForViewController(_ viewController: UIViewController) -> FamilyViewControllerAttributes? {
    guard let entry = registry[viewController],
      let attributes = scrollView.cache.entry(for: entry.view) else { return nil }
    return attributes
  }

  /// Remove stray views from view hierarchy.
  @discardableResult
  public func purgeRemovedViews() -> Self {
    for (controller, container) in registry where controller.parent == nil {
      if container.view.superview is FamilyWrapperView {
        container.view.superview?.removeFromSuperview()
      }

      container.view.removeFromSuperview()
      container.observer.invalidate()
      registry.removeValue(forKey: controller)
    }

    return self
  }

  // MARK: - Private methods

  /// Configure constraints for the scroll view.
  private func configureConstraints() {
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.deactivate(constraints)
    constraints.removeAll()
    if #available(iOS 11.0, tvOS 11.0, *) {
      let topAnchor = safeAreaLayoutConstraints
        ? view.safeAreaLayoutGuide.topAnchor
        : view.topAnchor

      let bottomAnchor = safeAreaLayoutConstraints
        ? view.safeAreaLayoutGuide.bottomAnchor
        : view.bottomAnchor

      constraints.append(contentsOf: [
        scrollView.topAnchor.constraint(equalTo: topAnchor),
        scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
        scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    } else {
      if #available(iOS 9.0, *) {
        constraints.append(contentsOf: [
          scrollView.topAnchor.constraint(equalTo: topLayoutGuide.topAnchor),
          scrollView.bottomAnchor.constraint(equalTo: bottomLayoutGuide.topAnchor),
          scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
          scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
          ])
      }
    }
    NSLayoutConstraint.activate(constraints)
  }

  public func wrappedViewIfNeeded(_ view: UIView) -> UIView {
    if let wrapperView = view.superview as? FamilyWrapperView {
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
  private func addOrInsertView(_ view: UIView, at index: Int? = nil) {
    if let index = index, index < scrollView.documentView.subviews.count {
      scrollView.documentView.insertSubview(view, at: index)
    } else {
      scrollView.documentView.addSubview(view)
    }

    if #available(iOS 11.0, *, tvOS 11.0, *) {
      (view as? UIScrollView)?.contentInsetAdjustmentBehavior = .never
    }
  }

  /// Resolves which view should be used to add into the view hierarchy.
  ///
  /// - Parameter childController: The child view controller that is used
  ///                              to find the view.
  /// - Returns: A view that matches the criteria depending on the
  ///            view controllers type.
  private func viewToAdd(from childController: UIViewController) -> View {
    let view: UIView

    switch childController {
    case let collectionViewController as UICollectionViewController:
      if let collectionView = collectionViewController.collectionView {
        view = collectionView
      } else {
        assertionFailure("Unable to resolve collection view from controller.")
        return childController.view
      }
    case let tableViewController as UITableViewController:
      view = tableViewController.tableView
    default:
      view = childController.view
    }

    return view
  }

  private func observe(_ childController: UIViewController) -> NSKeyValueObservation {
    let observer = childController.observe(\.parent, options: [.new, .old]) { [weak self] _, _ in
      self?.purgeRemovedViews()
    }
    return observer
  }
}
