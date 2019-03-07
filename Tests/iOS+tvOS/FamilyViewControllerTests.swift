import XCTest
@testable import Family

private extension UIViewController {
  func prepareViewController() {
    let _ = view
    viewWillAppear(false)
    viewDidAppear(false)
    viewWillLayoutSubviews()
  }
}

class FamilyViewControllerTests: XCTestCase {
  var familyViewController: FamilyViewController!

  class MockViewController: UIViewController {
    lazy var scrollView: UIScrollView = {
      let scrollView = UIScrollView()
      scrollView.contentSize = CGSize(width: 200, height: 200)
      return scrollView
    }()
  }

  override func setUp() {
    super.setUp()
    familyViewController = FamilyViewController()
    familyViewController.prepareViewController()
  }

  func testAddingChildViewController() {
    let viewController = UIViewController()
    familyViewController.addChild(viewController)
    XCTAssertEqual(viewController.parent, familyViewController)
    XCTAssertEqual(viewController.view.frame, familyViewController.view.frame)
  }

  func testAddingMultipleChildViewControllers() {
    let firstViewController = UIViewController()
    let secondViewController = UIViewController()
    let thirdViewController = UIViewController()

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

    var wrapperView = (familyViewController.scrollView.documentView.subviews[0] as? FamilyWrapperView)
    XCTAssertEqual(wrapperView, firstViewController.view.superview)
    wrapperView = (familyViewController.scrollView.documentView.subviews[1] as? FamilyWrapperView)
    XCTAssertEqual(wrapperView, secondViewController.view.superview)
    wrapperView = (familyViewController.scrollView.documentView.subviews[2] as? FamilyWrapperView)
    XCTAssertEqual(wrapperView, thirdViewController.view.superview)

    XCTAssertEqual(familyViewController.scrollView.contentSize.height, 1500)
    secondViewController.view.isHidden = true

    #if os(iOS)
    XCTAssertEqual(familyViewController.scrollView.contentSize.height, 1000)
    #else
    XCTAssertEqual(familyViewController.scrollView.contentSize.height, 1080)
    #endif
  }

  func testAddingCustomViewFromController() {
    let mockedViewController1 = MockViewController()
    let mockedViewController2 = MockViewController()
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
    let viewController = UIViewController()
    familyViewController.addChild(viewController, height: 200)
    XCTAssertEqual(viewController.parent, familyViewController)
    XCTAssertEqual(viewController.view.frame.size.width, familyViewController.view.frame.width)
    XCTAssertEqual(viewController.view.frame.size.height, 200)
  }

  func testFamilyControllerWithTabBar() {
    let tabBarController = UITabBarController()
    tabBarController.setViewControllers([familyViewController], animated: false)
    XCTAssertEqual(familyViewController.scrollView.contentInset, .zero)

    familyViewController.viewWillAppear(false)

    if #available(iOS 11.0, *) {} else {
      XCTAssertEqual(familyViewController.scrollView.contentInset.bottom,
                     tabBarController.tabBar.frame.size.height)
    }
    XCTAssertEqual(familyViewController.scrollView.contentInset.bottom,
                   familyViewController.scrollView.scrollIndicatorInsets.bottom)
  }

  func testViewControllersInLayoutOrder() {
    let familyViewController = FamilyViewController()

    let controller1 = UIViewController()
    let controller2 = UIViewController()
    let controller3 = UIViewController()

    familyViewController.addChild(controller1, at: 0)
    familyViewController.addChild(controller3, at: 1)
    familyViewController.addChild(controller2, at: 0)

    XCTAssertEqual(familyViewController.viewControllersInLayoutOrder(),
                   [controller2, controller1, controller3])
  }

  func testViewControllerIsVisibleMethods() {
    let familyViewController = FamilyViewController()
    familyViewController.view.frame.size = CGSize(width: 375, height: 667)
    familyViewController.prepareViewController()

    let controller1 = UIViewController()
    let controller2 = UIViewController()
    let controller3 = UIViewController()
    let controller4 = UIViewController()

    [controller1, controller2, controller3].forEach {
      $0.view.frame.size = CGSize(width: 375, height: 667)
    }

    familyViewController.addChildren([
      controller1, controller2, controller3
    ])

    XCTAssertTrue(familyViewController.viewControllerIsVisible(controller1))
    XCTAssertTrue(familyViewController.viewControllerIsFullyVisible(controller1))

    XCTAssertFalse(familyViewController.viewControllerIsVisible(controller2))
    XCTAssertFalse(familyViewController.viewControllerIsFullyVisible(controller2))

    XCTAssertFalse(familyViewController.viewControllerIsVisible(controller3))
    XCTAssertFalse(familyViewController.viewControllerIsFullyVisible(controller3))

    familyViewController.scrollView.setContentOffset(.init(x: 0, y: 667 / 2), animated: false)

    XCTAssertTrue(familyViewController.viewControllerIsVisible(controller1))
    XCTAssertFalse(familyViewController.viewControllerIsFullyVisible(controller1))

    XCTAssertTrue(familyViewController.viewControllerIsVisible(controller2))
    XCTAssertFalse(familyViewController.viewControllerIsFullyVisible(controller2))

    XCTAssertFalse(familyViewController.viewControllerIsVisible(controller3))
    XCTAssertFalse(familyViewController.viewControllerIsFullyVisible(controller3))

    familyViewController.scrollView.setContentOffset(.init(x: 0, y: 667), animated: false)

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
    familyViewController.prepareViewController()

    let controller1 = UIViewController()
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
    familyViewController.prepareViewController()

    let controller1 = UIViewController()
    controller1.title = "Controller 1"
    let controller2 = UIViewController()
    controller2.title = "Controller 2"
    let controller3 = UIViewController()
    controller3.title = "Controller 3"

    familyViewController.performBatchUpdates({ controller in
      controller.addChild(controller1)
      controller.addChild(controller2)
      controller.addChild(controller3)
      controller.moveChild(controller3, to: 0)
    }, completion: nil)

    familyViewController.view.layoutIfNeeded()

    XCTAssertEqual(familyViewController.viewControllersInLayoutOrder().compactMap({ $0.title }),
                   ["Controller 3", "Controller 1", "Controller 2"])
  }

  func testChangingViewSize() {
    let window = UIWindow(frame: .init(origin: .zero, size: CGSize(width: 375, height: 667)))
    let familyViewController = FamilyViewController()
    window.rootViewController = familyViewController
    familyViewController.view.frame.size = CGSize(width: 375, height: 667)
    familyViewController.prepareViewController()

    let controller1 = UIViewController()
    controller1.title = "Controller 1"
    controller1.view.frame.size = CGSize(width: 375, height: 200)

    familyViewController.addChild(controller1)

    let wrapperView = controller1.view.superview
    XCTAssertEqual(controller1.view.frame.size, wrapperView?.frame.size)

    controller1.view.frame.size.height = 400
    XCTAssertEqual(controller1.view.frame.size, wrapperView?.frame.size)
  }
}
