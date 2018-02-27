import Cocoa

public class FamilyViewController: NSViewController, FamilyFriendly {
  public lazy var scrollView: FamilyScrollView = .init()

  public override func loadView() {
    let view = NSView()
    view.autoresizingMask = [.width]
    view.autoresizesSubviews = true
    self.view = view
  }

  override public func viewDidLoad() {
    super.viewDidLoad()
    view.addSubview(scrollView)
    scrollView.autoresizingMask = [.width]
    configureConstraints()
  }

  private func configureConstraints() {
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    if #available(OSX 10.11, *) {
      scrollView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
      scrollView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
      scrollView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
      scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
    }
  }

  override open func addChildViewController(_ childController: ViewController) {
    super.addChildViewController(childController)
    childController.view.frame.size.width = view.bounds.width
    scrollView.familyContentView.addSubview(childController.view)
    scrollView.frame = view.bounds
  }

  public func addChildViewController(_ childController: ViewController, height: CGFloat) {
    addChildViewController(childController)
    childController.view.translatesAutoresizingMaskIntoConstraints = true
    childController.view.autoresizingMask = [.width]
    childController.view.frame.size.height = height
    childController.view.frame.size.width = view.bounds.width
    scrollView.frame = view.bounds
  }

  public func addChildViewController<T>(_ childController: T, view closure: (T) -> View) where T : ViewController {
    super.addChildViewController(childController)
    let childView = closure(childController)
    childView.frame = view.bounds
    view.addSubview(childController.view)
    childController.view.isHidden = true
    childController.view.frame.size.width = view.bounds.width
    scrollView.familyContentView.addSubview(childView)
    scrollView.frame = view.bounds
  }

  public func addChildViewControllers(_ childControllers: NSViewController ...) {
    addChildViewControllers(childControllers)
  }

  public func addChildViewControllers(_ childControllers: [NSViewController]) {
    for childController in childControllers {
      addChildViewController(childController)
    }
  }
}
