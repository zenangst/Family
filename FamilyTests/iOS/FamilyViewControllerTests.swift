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
    familyViewController.addChildViewController(viewController)
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

    familyViewController.addChildViewControllers(firstViewController,
                                                 secondViewController,
                                                 thirdViewController)
    XCTAssertEqual(familyViewController.childViewControllers.count, 3)
    XCTAssertEqual(firstViewController.parent, familyViewController)
    XCTAssertEqual(secondViewController.parent, familyViewController)
    XCTAssertEqual(thirdViewController.parent, familyViewController)

    var wrapperView = (familyViewController.scrollView.contentView.subviews[0] as? FamilyWrapperView)
    XCTAssertEqual(wrapperView, firstViewController.view.superview)
    wrapperView = (familyViewController.scrollView.contentView.subviews[1] as? FamilyWrapperView)
    XCTAssertEqual(wrapperView, secondViewController.view.superview)
    wrapperView = (familyViewController.scrollView.contentView.subviews[2] as? FamilyWrapperView)
    XCTAssertEqual(wrapperView, thirdViewController.view.superview)

    XCTAssertEqual(familyViewController.scrollView.contentSize.height, 1500)
    secondViewController.view.isHidden = true
    XCTAssertEqual(familyViewController.scrollView.contentSize.height, 1000)
  }

  func testAddingCustomViewFromController() {
    let mockedViewController = MockViewController()
    familyViewController.addChildViewController(mockedViewController, view: { $0.scrollView })

    XCTAssertEqual(mockedViewController.parent, familyViewController)
    XCTAssertEqual(familyViewController.childViewControllers.count, 1)
    XCTAssertEqual(familyViewController.scrollView.contentView, mockedViewController.scrollView.superview)
  }

  func testAddingChildViewControllerWithConstraintedHeight() {
    let viewController = UIViewController()
    familyViewController.addChildViewController(viewController, height: 200)
    XCTAssertEqual(viewController.parent, familyViewController)
    XCTAssertEqual(viewController.view.frame.size.width, familyViewController.view.frame.width)
    XCTAssertEqual(viewController.view.frame.size.height, 200)
  }

  func testFamilyControllerWithTabBar() {
    let tabBarController = UITabBarController()
    tabBarController.setViewControllers([familyViewController], animated: false)
    XCTAssertEqual(familyViewController.scrollView.contentInset, .zero)

    familyViewController.viewWillAppear(false)

    XCTAssertEqual(familyViewController.scrollView.contentInset.bottom,
                   tabBarController.tabBar.frame.size.height)
    XCTAssertEqual(familyViewController.scrollView.contentInset.bottom,
                   familyViewController.scrollView.scrollIndicatorInsets.bottom)
  }
}
