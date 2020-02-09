import XCTest
@testable import Family

class MockedViewController: NSViewController {
  override func loadView() {
    view = NSView()
  }
}

class FamilyScrollViewTests: XCTestCase {
  class CollectionViewFlowLayoutMock: NSCollectionViewFlowLayout {
    var contentSize: CGSize = CGSize(width: 100, height: 100)
    override var collectionViewContentSize: NSSize { return self.contentSize }
  }

  static let mockFrame = CGRect(origin: .zero, size: CGSize(width: 500, height: 1000))
  var window: NSWindow!
  var scrollView: FamilyScrollView!

  override func setUp() {
    super.setUp()
    let contentViewController = MockedViewController()
    contentViewController.view.frame = FamilyScrollViewTests.mockFrame
    window = NSWindow(contentViewController: contentViewController)
    scrollView = FamilyScrollView()
    contentViewController.view.addSubview(scrollView)
    window.makeKeyAndOrderFront(nil)
  }

  func testLayoutAlgorithm() {
    let size = CGSize(width: 500, height: 250)
    let mockedScrollView1 = NSScrollView(frame: CGRect(origin: .zero, size: size))
    let mockedScrollView2 = NSScrollView(frame: CGRect(origin: .zero, size: size))
    let mockedScrollView3 = NSScrollView(frame: CGRect(origin: .zero, size: size))
    let mockedScrollView4 = NSScrollView(frame: CGRect(origin: .zero, size: size))

    [mockedScrollView1, mockedScrollView2, mockedScrollView3, mockedScrollView4].forEach {
      let collectionView = NSCollectionView()
      let layout = CollectionViewFlowLayoutMock()
      layout.contentSize = size
      collectionView.collectionViewLayout = layout
      $0.documentView = collectionView
      scrollView.documentView?.addSubview($0)
    }

    scrollView.layout()

    XCTAssertEqual(mockedScrollView1.frame, CGRect(origin: .zero, size: size))
    XCTAssertEqual(mockedScrollView2.frame, CGRect(origin: CGPoint(x: 0, y: 250), size: size))
    XCTAssertEqual(mockedScrollView3.frame, CGRect(origin: CGPoint(x: 0, y: 500), size: size))
    XCTAssertEqual(mockedScrollView4.frame, CGRect(origin: CGPoint(x: 0, y: 750), size: size))

    // Check that layout algorithm takes spacing between views into account.

    scrollView.margins = .init(top: 0, left: 0, bottom: 10, right: 0)
    scrollView.layoutViews(withDuration: nil, force: false, completion: nil)

    XCTAssertEqual(mockedScrollView1.frame, CGRect(origin: .zero, size: size))
    XCTAssertEqual(mockedScrollView2.frame, CGRect(origin: CGPoint(x: 0, y: 250 + scrollView.margins.bottom), size: size))
    XCTAssertEqual(mockedScrollView3.frame, CGRect(origin: CGPoint(x: 0, y: 500 + scrollView.margins.bottom * 2), size: size))
    XCTAssertEqual(mockedScrollView4.frame, CGRect(origin: CGPoint(x: 0, y: 750 + scrollView.margins.bottom * 3),
                                                   size: CGSize(width: size.width, height: size.height)))
    scrollView.layout()
    XCTAssertEqual(scrollView.documentView?.frame.size.height, 1040)

    scrollView.margins = .init(top: 0, left: 0, bottom: 0, right: 0)

    scrollView.addMargins(.init(top: 0, left: 0, bottom: 10, right: 0), for: mockedScrollView1.documentView!)
    scrollView.addMargins(.init(top: 0, left: 0, bottom: 10, right: 0), for: mockedScrollView3.documentView!)
    scrollView.layoutViews(withDuration: nil, force: false, completion: nil)

    XCTAssertEqual(mockedScrollView1.frame, CGRect(origin: .zero, size: size))
    XCTAssertEqual(mockedScrollView2.frame, CGRect(origin: CGPoint(x: 0, y: 250 + 10), size: size))
    XCTAssertEqual(mockedScrollView3.frame, CGRect(origin: CGPoint(x: 0, y: 500 + 10), size: size))
    XCTAssertEqual(mockedScrollView4.frame, CGRect(origin: CGPoint(x: 0, y: 750 + 20),
                                                   size: CGSize(width: size.width, height: size.height)))
    XCTAssertEqual(scrollView.documentView?.frame.size.height, 1020)

    scrollView.addMargins(.init(top: 0, left: 0, bottom: 0, right: 0), for: mockedScrollView1.documentView!)
    scrollView.addMargins(.init(top: 0, left: 0, bottom: 0, right: 0), for: mockedScrollView3.documentView!)
    scrollView.layoutViews(withDuration: nil, force: false, completion: nil)

    scrollView.contentOffset.y = 250
    scrollView.layoutViews(withDuration: nil, force: false, completion: nil)
    scrollView.layout()

    let lastSize = CGSize(width: 500, height: 250)

    XCTAssertEqual(mockedScrollView1.frame, CGRect(origin: CGPoint(x: 0, y: 0), size: size))
    XCTAssertEqual(mockedScrollView2.frame, CGRect(origin: CGPoint(x: 0, y: 250), size: size))
    XCTAssertEqual(mockedScrollView3.frame, CGRect(origin: CGPoint(x: 0, y: 500), size: size))
    XCTAssertEqual(mockedScrollView4.frame, CGRect(origin: CGPoint(x: 0, y: 750), size: lastSize))
    XCTAssertEqual(scrollView.documentView?.frame.size.height, 1000)

    scrollView.contentOffset.y = 500
    scrollView.layout()
    scrollView.layoutViews(withDuration: nil, force: false, completion: nil)

    XCTAssertEqual(mockedScrollView1.frame, CGRect(origin: CGPoint(x: 0, y: 0), size: size))
    XCTAssertEqual(mockedScrollView2.frame, CGRect(origin: CGPoint(x: 0, y: 250), size: size))
    XCTAssertEqual(mockedScrollView3.frame, CGRect(origin: CGPoint(x: 0, y: 500), size: size))
    XCTAssertEqual(mockedScrollView4.frame, CGRect(origin: CGPoint(x: 0, y: 750), size: lastSize))

    scrollView.contentOffset.y = 750
    scrollView.layoutViews(withDuration: nil, force: false, completion: nil)

    XCTAssertEqual(mockedScrollView1.frame, CGRect(origin: CGPoint(x: 0, y: 0), size: size))
    XCTAssertEqual(mockedScrollView2.frame, CGRect(origin: CGPoint(x: 0, y: 250), size: size))
    XCTAssertEqual(mockedScrollView3.frame, CGRect(origin: CGPoint(x: 0, y: 500), size: size))
    XCTAssertEqual(mockedScrollView4.frame, CGRect(origin: CGPoint(x: 0, y: 750), size: lastSize))

    let rect = CGRect(origin: .zero, size: CGSize(width: 500, height: 1250))
    let window = NSWindow()
    window.contentView = scrollView
    window.setFrame(rect, display: true)

    XCTAssertEqual(mockedScrollView1.frame, CGRect(origin: CGPoint(x: 0, y: 0), size: size))
    XCTAssertEqual(mockedScrollView2.frame, CGRect(origin: CGPoint(x: 0, y: 250), size: size))
    XCTAssertEqual(mockedScrollView3.frame, CGRect(origin: CGPoint(x: 0, y: 500), size: size))
    XCTAssertEqual(mockedScrollView4.frame, CGRect(origin: CGPoint(x: 0, y: 750), size: lastSize))

    scrollView = nil
  }
}

