import XCTest
@testable import Family

private extension NSViewController {
  func prepareViewController() {
    let _ = view
    viewWillAppear()
    viewDidAppear()
  }
}

class FamilyViewControllerTests: XCTestCase {
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
    familyViewController.prepareViewController()
    NSAnimationContext.current.duration = 0.0
  }

  func testAddingChildViewController() {
    let viewController = MockViewController()
    familyViewController.addChildViewController(viewController)
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

    familyViewController.addChildViewControllers(firstViewController,
                                                 secondViewController,
                                                 thirdViewController)
    XCTAssertEqual(familyViewController.childViewControllers.count, 3)
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

    familyViewController.scrollView.layoutViews(withDuration: 0)
    XCTAssertEqual(familyViewController.scrollView.documentView?.frame.size.height, 1500)
    secondViewController.view.isHidden = true
    XCTAssertEqual(familyViewController.scrollView.documentView?.frame.size.height, 1000)
  }

  func testAddingCustomViewFromController() {
    let mockedViewController = MockScrollViewController()
    familyViewController.addChildViewController(mockedViewController, view: { $0.scrollView })

    XCTAssertEqual(mockedViewController.parent, familyViewController)
    XCTAssertEqual(familyViewController.childViewControllers.count, 1)
    XCTAssertEqual(familyViewController.scrollView.documentView, mockedViewController.scrollView.superview)
  }

  func testAddingChildViewControllerWithConstraintedHeight() {
    let viewController = MockViewController()
    familyViewController.addChildViewController(viewController, height: 200)
    XCTAssertEqual(viewController.parent, familyViewController)
    XCTAssertEqual(viewController.view.frame.size.width, familyViewController.view.frame.width)
    XCTAssertEqual(viewController.view.frame.size.height, 200)
  }
}
