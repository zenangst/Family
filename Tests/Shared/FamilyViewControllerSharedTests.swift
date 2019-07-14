import XCTest
@testable import Family

class FamilyViewControllerSharedTests: XCTestCase {
  func testMarginsAndPadding() {
    let childViewController = ChildViewController()
    childViewController.view.frame.size = CGSize(width: 500, height: 500)
    let insets = Insets(top: 10, left: 10, bottom: 10, right: 10)
    let backgroundView = View()
    let container = ContainerViewController(builder: { instance in
      instance.body {
        instance.add(childViewController)
          .margin(insets)
          .padding(insets)
          .background(.view(backgroundView))
      }
    })
    container.view.frame.size = CGSize(width: 500, height: 1000)
    container.scrollView.frame.size = CGSize(width: 500, height: 1000)
    #if os(macOS)
    container.loadView()
    container.scrollView.layoutViews(withDuration: nil, force: false, completion: nil)
    #else
    container.loadViewIfNeeded()
    container.scrollView.layoutViews()
    #endif


    let margins = container.margins(for: childViewController.view)
    let padding = container.padding(for: childViewController.view)

    XCTAssertEqual(margins.top, insets.top)
    XCTAssertEqual(margins.left, insets.left)
    XCTAssertEqual(margins.right, insets.right)
    XCTAssertEqual(margins.bottom, insets.bottom)

    XCTAssertEqual(padding.top, insets.top)
    XCTAssertEqual(padding.left, insets.left)
    XCTAssertEqual(padding.right, insets.right)
    XCTAssertEqual(padding.bottom, insets.bottom)

    XCTAssertEqual(container.scrollView.bounds, CGRect(origin: .zero, size: CGSize(width: 500, height: 1000)))
    XCTAssertEqual(childViewController.view.frame, CGRect(origin: .init(x: 10, y: 10),
                                                          size: CGSize(width: 460, height: 500)))

    #if os(macOS)
    XCTAssertEqual(backgroundView.superview, container.scrollView.documentView!)
    XCTAssertEqual(childViewController.view.enclosingScrollView?.frame, CGRect(origin: .init(x: 10, y: 10),
                                                                               size: CGSize(width: 480, height: 520)))
    #else
    XCTAssertEqual(backgroundView.superview, container.scrollView)
    XCTAssertEqual(childViewController.view.superview?.frame, CGRect(origin: .init(x: 10, y: 20),
                                                                     size: CGSize(width: 480, height: 500)))
    #endif


    XCTAssertEqual(backgroundView.frame, CGRect(origin: .init(x: 10, y: 10),
                                                size: CGSize(width: 480, height: 520)))
  }
}

fileprivate class ChildViewController: ViewController {
  override func loadView() {
    view = View()
  }
}
fileprivate class BackgroundView: View {}

fileprivate class ContainerViewController: FamilyViewController {
  let builder: (ContainerViewController) -> Void

  init(builder: @escaping (ContainerViewController) -> Void) {
    self.builder = builder
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func loadView() {
    view = View()
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    builder(self)
  }
}
