import XCTest
@testable import Family

class FamilyViewControllerTests: XCTestCase {
  var window: NSWindow!
  var familyViewController: FamilyViewController!

  class MockScrollViewController: MockViewController {
    lazy var scrollView: NSScrollView = {
      let scrollView = NSScrollView()
      let view = NSView()
      view.frame.size = CGSize(width: 200, height: 200)
      scrollView.documentView = view
      return scrollView
    }()
  }

  class MockViewController: NSViewController {
    override func loadView() {
      self.view = NSView()
    }
  }

  override func setUp() {
    super.setUp()
    familyViewController = FamilyViewController()
    familyViewController.view.frame.size = CGSize(width: 375, height: 667)
    window = NSWindow(contentViewController: familyViewController)
    window.makeKeyAndOrderFront(nil)
    NSAnimationContext.current.duration = 0.0
  }

  func testAddingChildViewController() {
    let viewController = MockViewController()
    viewController.view.frame.size.height = 667
    familyViewController.addChild(viewController)
    XCTAssertEqual(viewController.parent, familyViewController)
    XCTAssertEqual(viewController.view.frame, familyViewController.view.frame)
  }

  func testAddingMultipleChildViewControllers() {
    let firstViewController = MockViewController()
    let secondViewController = MockViewController()
    let thirdViewController = MockViewController()

    firstViewController.view.frame.size.height = 500
    secondViewController.view.frame.size.height = 500
    thirdViewController.view.frame.size.height = 500

    familyViewController.addChildren(firstViewController,
                                                 secondViewController,
                                                 thirdViewController)
    XCTAssertEqual(familyViewController.children.count, 3)
    XCTAssertEqual(firstViewController.parent, familyViewController)
    XCTAssertEqual(secondViewController.parent, familyViewController)
    XCTAssertEqual(thirdViewController.parent, familyViewController)

    let subviews = familyViewController.scrollView.contentView.documentView!.subviews

    var wrapperView = (subviews[0] as? FamilyWrapperView)
    XCTAssertEqual(wrapperView?.documentView, firstViewController.view)
    wrapperView = (subviews[1] as? FamilyWrapperView)
    XCTAssertEqual(wrapperView?.documentView, secondViewController.view)
    wrapperView = (subviews[2] as? FamilyWrapperView)
    XCTAssertEqual(wrapperView?.documentView, thirdViewController.view)

    familyViewController.scrollView.layout()
    familyViewController.scrollView.layoutViews(withDuration: 0, force: false, completion: nil)
    XCTAssertEqual(familyViewController.scrollView.documentView?.frame.size.height, 1500)
    secondViewController.view.isHidden = true
    familyViewController.scrollView.layout()
    XCTAssertEqual(familyViewController.scrollView.documentView?.frame.size.height, 1000)
  }

  func testAddingCustomViewFromController() {
    let mockedViewController1 = MockScrollViewController()
    let mockedViewController2 = MockScrollViewController()
    familyViewController.addChild(mockedViewController1, view: { $0.scrollView })
    familyViewController.addChild(mockedViewController2, view: { $0.scrollView })
    
    XCTAssertEqual(mockedViewController1.parent, familyViewController)
    XCTAssertEqual(mockedViewController2.parent, familyViewController)
    XCTAssertEqual(familyViewController.children.count, 2)
    XCTAssertEqual(familyViewController.scrollView.documentView, mockedViewController1.scrollView.superview)
    XCTAssertEqual(familyViewController.scrollView.documentView, mockedViewController2.scrollView.superview)
    
    XCTAssertEqual(familyViewController.registry.count, 2)
    mockedViewController1.removeFromParent()
    XCTAssertEqual(familyViewController.registry.count, 1)
    mockedViewController2.removeFromParent()
    XCTAssertEqual(familyViewController.registry.count, 0)
  }

  func testAddingChildViewControllerWithConstraintedHeight() {
    let viewController = MockViewController()
    familyViewController.addChild(viewController, height: 200)
    XCTAssertEqual(viewController.parent, familyViewController)
    XCTAssertEqual(viewController.view.frame.size.width, familyViewController.view.frame.width)
    XCTAssertEqual(viewController.view.frame.size.height, 200)
  }

  func testViewControllersInLayoutOrder() {
    let familyViewController = FamilyViewController()
    let controller1 = MockViewController()
    let controller2 = MockViewController()
    let controller3 = MockViewController()

    familyViewController.addChild(controller1, at: 0)
    familyViewController.addChild(controller3, at: 1)
    familyViewController.addChild(controller2, at: 0)

    let expected = [controller2, controller1, controller3]
    let result = familyViewController.viewControllersInLayoutOrder()

    XCTAssertEqual(result, expected)
  }

  func testViewControllerIsVisibleMethods() {
    let familyViewController = FamilyViewController()
    familyViewController.view.frame.size = CGSize(width: 375, height: 667)

    let window = NSWindow(contentViewController: familyViewController)
    window.makeKeyAndOrderFront(nil)

    let controller1 = MockViewController()
    let controller2 = MockViewController()
    let controller3 = MockViewController()
    let controller4 = MockViewController()

    [controller1, controller2, controller3, controller4].forEach {
      $0.view.frame.size = CGSize(width: 375, height: 667)
    }

    familyViewController.addChildren([
      controller1, controller2, controller3, controller4
      ])

    XCTAssertTrue(familyViewController.viewControllerIsVisible(controller1))
    XCTAssertTrue(familyViewController.viewControllerIsFullyVisible(controller1))

    XCTAssertFalse(familyViewController.viewControllerIsVisible(controller2))
    XCTAssertFalse(familyViewController.viewControllerIsFullyVisible(controller2))

    XCTAssertFalse(familyViewController.viewControllerIsVisible(controller3))
    XCTAssertFalse(familyViewController.viewControllerIsFullyVisible(controller3))

    XCTAssertFalse(familyViewController.viewControllerIsVisible(controller4))
    XCTAssertFalse(familyViewController.viewControllerIsFullyVisible(controller4))

    familyViewController.scrollView.contentOffset = .init(x: 0, y: 667 / 2)

    XCTAssertTrue(familyViewController.viewControllerIsVisible(controller1))
    XCTAssertFalse(familyViewController.viewControllerIsFullyVisible(controller1))

    XCTAssertTrue(familyViewController.viewControllerIsVisible(controller2))
    XCTAssertFalse(familyViewController.viewControllerIsFullyVisible(controller2))

    XCTAssertFalse(familyViewController.viewControllerIsVisible(controller3))
    XCTAssertFalse(familyViewController.viewControllerIsFullyVisible(controller3))

    XCTAssertFalse(familyViewController.viewControllerIsVisible(controller4))
    XCTAssertFalse(familyViewController.viewControllerIsFullyVisible(controller4))

    familyViewController.scrollView.contentOffset = .init(x: 0, y: 667)

    XCTAssertFalse(familyViewController.viewControllerIsVisible(controller1))
    XCTAssertFalse(familyViewController.viewControllerIsFullyVisible(controller1))

    XCTAssertTrue(familyViewController.viewControllerIsVisible(controller2))
    XCTAssertTrue(familyViewController.viewControllerIsFullyVisible(controller2))

    XCTAssertFalse(familyViewController.viewControllerIsVisible(controller3))
    XCTAssertFalse(familyViewController.viewControllerIsFullyVisible(controller3))

    XCTAssertFalse(familyViewController.viewControllerIsVisible(controller4))
    XCTAssertFalse(familyViewController.viewControllerIsFullyVisible(controller4))
  }

  func testAttributesForViewController() {
    let familyViewController = FamilyViewController()
    familyViewController.view.frame.size = CGSize(width: 375, height: 667)
    let window = NSWindow(contentViewController: familyViewController)
    window.makeKeyAndOrderFront(nil)

    let controller1 = MockViewController()
    controller1.view.frame.size = CGSize(width: 375, height: 667)

    familyViewController.addChild(controller1)

    let attributes = familyViewController.attributesForViewController(controller1)

    XCTAssertEqual(attributes?.contentSize, CGSize(width: 375, height: 667))
    XCTAssertEqual(attributes?.maxY, 667)
    XCTAssertEqual(attributes?.view, controller1.view)
    XCTAssertEqual(attributes?.origin, CGPoint(x: 0, y: 0))
  }

  func testBatchUpdates() {
    let familyViewController = FamilyViewController()
    familyViewController.view.frame.size = CGSize(width: 375, height: 667)

    let controller1 = MockViewController()
    controller1.title = "Controller 1"
    let controller2 = MockViewController()
    controller2.title = "Controller 2"
    let controller3 = MockViewController()
    controller3.title = "Controller 3"

    familyViewController.performBatchUpdates({ controller in
      controller.addChild(controller1)
      controller.addChild(controller2)
      controller.addChild(controller3)
      controller.moveChild(controller3, to: 0)
    }, completion: nil)

    familyViewController.view.layoutSubtreeIfNeeded()

    XCTAssertEqual(familyViewController.viewControllersInLayoutOrder().compactMap({ $0.title }),
                   ["Controller 3", "Controller 1", "Controller 2"])
  }

  func testChangingViewSize() {
    let familyViewController = FamilyViewController()
    let window = NSWindow(contentViewController: familyViewController)
    window.setFrame(NSRect.init(origin: .zero, size: CGSize(width: 375, height: 667)), display: false)
    familyViewController.view.frame.size = CGSize(width: 375, height: 667)

    let controller1 = MockViewController()
    controller1.title = "Controller 1"
    controller1.view.frame.size = CGSize(width: 375, height: 200)

    familyViewController.addChild(controller1)
    familyViewController.scrollView.layoutViews(withDuration: nil, force: false, completion: nil)

    let wrapperView = controller1.view.enclosingScrollView
    XCTAssertEqual(controller1.view.frame.size.height, wrapperView?.frame.size.height)

    controller1.view.frame.size.height = 400
    XCTAssertEqual(controller1.view.frame.size.height, wrapperView?.frame.size.height)
  }
}
