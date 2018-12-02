import Cocoa

open class FamilyViewController: NSViewController, FamilyFriendly {
  public lazy var scrollView: FamilyScrollView = .init()
  /// The scroll view constraints.
  public var constraints = [NSLayoutConstraint]()
  var registry = [ViewController: View]()
  var observer: NSKeyValueObservation?

  deinit {
    children.forEach { $0.removeFromParent() }
    purgeRemovedViews()
  }

  open override func loadView() {
    let view = NSView()
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
  }

  private func configureConstraints() {
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    if #available(OSX 10.11, *) {
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
    scrollView.familyContentView.addSubview(childController.view)
    scrollView.frame = view.bounds
    registry[childController] = childController.view
  }

  public func addChild(_ childController: ViewController, customSpacing spacing: CGFloat? = nil, height: CGFloat) {
    addChild(childController)
    childController.view.translatesAutoresizingMaskIntoConstraints = true
    childController.view.autoresizingMask = [.width]
    childController.view.frame.size.height = height
    childController.view.frame.size.width = view.bounds.width
    scrollView.frame = view.bounds

    if let spacing = spacing {
      setCustomSpacing(spacing, after: childController.view)
    }
  }

  public func addChild<T: ViewController>(_ childController: T, customSpacing spacing: CGFloat? = nil, view closure: (T) -> View) {
    super.addChild(childController)
    view.addSubview(childController.view)
    childController.view.frame.size = .zero
    let childView = closure(childController)
    addView(childView, customSpacing: spacing)
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

  public func addView(_ subview: View, customSpacing spacing: CGFloat? = nil, withHeight height: CGFloat? = nil) {
    if let height = height {
      subview.frame.size.width = view.bounds.size.width
      subview.frame.size.height = height
    } else {
      subview.frame.size.width = view.bounds.width
    }
    scrollView.familyContentView.addSubview(subview)
    scrollView.frame = view.bounds

    if let spacing = spacing {
      setCustomSpacing(spacing, after: view)
    }
  }

  public func customSpacing(after view: View) -> CGFloat {
    return scrollView.customSpacing(after: view)
  }

  public func setCustomSpacing(_ spacing: CGFloat, after view: View) {
    scrollView.setCustomSpacing(spacing, after: view)
  }

  func purgeRemovedViews() {
    for (controller, view) in registry where controller.parent == nil {
      view.enclosingScrollView?.removeFromSuperview()
      registry.removeValue(forKey: controller)
    }
  }
}
