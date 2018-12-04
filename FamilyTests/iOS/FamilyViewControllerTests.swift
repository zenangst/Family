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
}
