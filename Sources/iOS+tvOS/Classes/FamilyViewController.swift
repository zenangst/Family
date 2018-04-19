import UIKit

/// This class is a `UIViewController` that adds some convenience methods
/// when using child view controllers to render your UI. The convenience methods
/// invoke the approriate child view controller related methods in sequence and
/// adds the controllers view or custom view to view heirarcy inside the
/// content view of the `FamilyScrollView`.
open class FamilyViewController: UIViewController, FamilyFriendly {
//  var observers = [NSKeyValueObservation]()
  var registry = [ViewController : (view: View, observer: NSKeyValueObservation)]()

  /// A custom implementation of a `UIScrollView` that handles continious scrolling
  /// when using scroll views inside of scroll view.
  public lazy var scrollView: FamilyScrollView = FamilyScrollView()

  deinit {
    childViewControllers.forEach { $0.removeFromParentViewController() }
    purgeRemovedViews()
  }

  /// Called after the controller's view is loaded into memory.
  open override func viewDidLoad() {
    super.viewDidLoad()

    view.addSubview(scrollView)
    scrollView.frame = view.bounds
    scrollView.alwaysBounceVertical = true
    scrollView.clipsToBounds = true

    configureConstraints()
  }

  /// Notifies the view controller that its view is about to be added to a view hierarchy.
  ///
  /// - Parameter animated: If true, the view is being added to the window using an animation.
  open override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    if let tabBarController = self.tabBarController, tabBarController.tabBar.isTranslucent {
      scrollView.contentInset.bottom = tabBarController.tabBar.frame.size.height
      scrollView.scrollIndicatorInsets.bottom = scrollView.contentInset.bottom
    }
  }

  /// Called to notify the view controller that its view is about to layout its subviews.
  override open func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()
    scrollView.frame = view.bounds
    scrollView.contentView.frame = scrollView.bounds
  }

  /// Configure constraints for the scroll view.
  private func configureConstraints() {
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    if #available(iOS 11.0, tvOS 11.0, *) {
      scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
      scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor).isActive = true
      scrollView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
      scrollView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
    } else {
      if #available(iOS 9.0, *) {
        scrollView.topAnchor.constraint(equalTo: topLayoutGuide.topAnchor).isActive = true
        scrollView.bottomAnchor.constraint(equalTo: bottomLayoutGuide.topAnchor).isActive = true
        scrollView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        scrollView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
      }
    }
  }

  /// Adds the specified view controller as a child of the current view controller.
  ///
  /// - Parameter childController: The view controller to be added as a child.
  override open func addChildViewController(_ childController: UIViewController) {
    purgeRemovedViews()
    childController.willMove(toParentViewController: self)
    super.addChildViewController(childController)

    switch childController {
    case let collectionViewController as UICollectionViewController:
      if let collectionView = collectionViewController.collectionView {
        scrollView.contentView.addSubview(collectionView)
      } else {
        assertionFailure("Unable to resolve collection view from controller.")
      }
    default:
      scrollView.contentView.addSubview(childController.view)
    }

    childController.didMove(toParentViewController: self)
    registry[childController] = (childController.view, observe(childController))
  }

  /// Adds the specified view controller as a child of the current view controller.
  ///
  /// - Parameters:
  ///   - childController: The view controller to be added as a child.
  ///   - height: The height that the child controllers should be constrained to.
  open func addChildViewController(_ childController: UIViewController, customSpacing: CGFloat? = nil, height: CGFloat) {
    childController.willMove(toParentViewController: self)
    super.addChildViewController(childController)
    scrollView.contentView.addSubview(childController.view)
    childController.didMove(toParentViewController: self)
    childController.view.translatesAutoresizingMaskIntoConstraints = true
    childController.view.autoresizingMask = []
    childController.view.frame.size.height = height
    registry[childController] = (childController.view, observe(childController))

    if let customSpacing = customSpacing {
      setCustomSpacing(customSpacing, after: childController.view)
    }
  }

  /// Adds the specified view controller as a child of the current view controller.
  /// The closure is used to resolve another view for the view controller that should
  /// be added into the view heirarcy.
  ///
  /// - Parameters:
  ///   - childController: The view controller to be added as a child.
  ///   - closure: A closure used to resolve a view other than `.view` on controller used
  ///              to render the view controller.
  public func addChildViewController<T: UIViewController>(_ childController: T, customSpacing spacing: CGFloat? = nil, view closure: (T) -> UIView) {
    childController.willMove(toParentViewController: self)
    super.addChildViewController(childController)
    view.addSubview(childController.view)
    childController.view.frame.size = .zero
    childController.view.isHidden = true
    let childView = closure(childController)
    addView(childView, customSpacing: spacing)
    childController.didMove(toParentViewController: self)
    registry[childController] = (childView, observe(childController))
  }

  /// Adds a collection of view controllers as children of the current view controller.
  ///
  /// - Parameter childControllers: The view controllers to be added as children.
  public func addChildViewControllers(_ childControllers: UIViewController ...) {
    addChildViewControllers(childControllers)
  }

  /// Adds a collection of view controllers as children of the current view controller.
  ///
  /// - Parameter childControllers: The view controllers to be added as children.
  public func addChildViewControllers(_ childControllers: [UIViewController]) {
    for childController in childControllers {
      addChildViewController(childController)
    }
  }

  public func addView(_ subview: View, withHeight height: CGFloat? = nil, customSpacing spacing: CGFloat? = nil) {
    if let height = height {
      subview.frame.size.width = view.bounds.size.width
      subview.frame.size.height = height
    } else {
      subview.frame.size.width = view.bounds.width
    }

    scrollView.contentView.addSubview(subview)
    scrollView.frame = view.bounds

    if let spacing = spacing {
      setCustomSpacing(spacing, after: subview)
    }
  }

  public func customSpacing(after view: View) -> CGFloat {
    return scrollView.customSpacing(after: view)
  }

  public func setCustomSpacing(_ spacing: CGFloat, after view: View) {
    scrollView.setCustomSpacing(spacing, after: view)
  }

  /// Remove stray views from view hierarcy.
  func purgeRemovedViews() {
    for (controller, container) in registry where controller.parent == nil {
      if container.view.superview is FamilyWrapperView {
        container.view.superview?.removeFromSuperview()
      }

      container.view.removeFromSuperview()
      container.observer.invalidate()
      registry.removeValue(forKey: controller)
    }
  }

  private func observe(_ childController: UIViewController) -> NSKeyValueObservation {
    let observer = childController.observe(\.parent, options: [.new, .old]) { [weak self] (_, value) in
      self?.purgeRemovedViews()
    }
    return observer
  }
}
