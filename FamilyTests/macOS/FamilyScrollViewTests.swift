import XCTest
@testable import Family

class FamilyScrollViewTests: XCTestCase {
  class CollectionViewFlowLayoutMock: NSCollectionViewFlowLayout {
    override var collectionViewContentSize: NSSize { return CGSize(width: 100, height: 100) }
  }

  static let mockFrame = CGRect(origin: .zero, size: CGSize(width: 500, height: 1000))
  let superview = NSView(frame: FamilyScrollViewTests.mockFrame)
  var scrollView: FamilyScrollView!

  override func setUp() {
    super.setUp()
    scrollView = FamilyScrollView()
  }

  override func tearDown() {
    super.tearDown()
    superview.subviews.forEach { $0.removeFromSuperview() }
  }

  func testLayoutAlgorithm() {
    superview.addSubview(scrollView)

    XCTAssertEqual(scrollView.contentSize, superview.bounds.size)
    // Should set the same height as the super view.
    XCTAssertEqual(superview.bounds, scrollView.frame)

    let size = CGSize(width: 500, height: 250)
    let mockedScrollView1 = NSScrollView(frame: CGRect(origin: .zero, size: size))
    let mockedScrollView2 = NSScrollView(frame: CGRect(origin: .zero, size: size))
    let mockedScrollView3 = NSScrollView(frame: CGRect(origin: .zero, size: size))
    let mockedScrollView4 = NSScrollView(frame: CGRect(origin: .zero, size: size))

    [mockedScrollView1, mockedScrollView2, mockedScrollView3, mockedScrollView4].forEach {
      $0.documentView = NSView()
      $0.documentView?.frame.size = size
      scrollView.documentView?.addSubview($0)
    }

    scrollView.layout()

    XCTAssertEqual(mockedScrollView1.frame, CGRect(origin: .zero, size: size))
    XCTAssertEqual(mockedScrollView2.frame, CGRect(origin: CGPoint(x: 0, y: 250), size: size))
    XCTAssertEqual(mockedScrollView3.frame, CGRect(origin: CGPoint(x: 0, y: 500), size: size))
    XCTAssertEqual(mockedScrollView4.frame, CGRect(origin: CGPoint(x: 0, y: 750), size: size))

    // Check that layout algorithm takes spacing between views into account.

    scrollView.insets = .init(top: 0, left: 0, bottom: 10, right: 0)
    scrollView.layoutViews()

    XCTAssertEqual(mockedScrollView1.frame, CGRect(origin: .zero, size: size))
    XCTAssertEqual(mockedScrollView2.frame, CGRect(origin: CGPoint(x: 0, y: 250 + scrollView.insets.bottom), size: size))
    XCTAssertEqual(mockedScrollView3.frame, CGRect(origin: CGPoint(x: 0, y: 500 + scrollView.insets.bottom * 2), size: size))
    XCTAssertEqual(mockedScrollView4.frame, CGRect(origin: CGPoint(x: 0, y: 750 + scrollView.insets.bottom * 3),
                                                   size: CGSize(width: size.width, height: size.height - scrollView.insets.bottom * 3)))
    scrollView.layout()
    XCTAssertEqual(scrollView.documentView?.frame.size.height, 1040)

    scrollView.insets = .init(top: 0, left: 0, bottom: 0, right: 0)

    scrollView.setCustomInsets(.init(top: 0, left: 0, bottom: 10, right: 0), for: mockedScrollView1)
    scrollView.setCustomInsets(.init(top: 0, left: 0, bottom: 10, right: 0), for: mockedScrollView3)
    scrollView.layoutViews()

    XCTAssertEqual(mockedScrollView1.frame, CGRect(origin: .zero, size: size))
    XCTAssertEqual(mockedScrollView2.frame, CGRect(origin: CGPoint(x: 0, y: 250 + 10), size: size))
    XCTAssertEqual(mockedScrollView3.frame, CGRect(origin: CGPoint(x: 0, y: 500 + 10), size: size))
    XCTAssertEqual(mockedScrollView4.frame, CGRect(origin: CGPoint(x: 0, y: 750 + 20),
                                                   size: CGSize(width: size.width, height: size.height - 30)))
    XCTAssertEqual(scrollView.documentView?.frame.size.height, 1000)

    scrollView.setCustomInsets(.init(top: 0, left: 0, bottom: 0, right: 0), for: mockedScrollView1)
    scrollView.setCustomInsets(.init(top: 0, left: 0, bottom: 0, right: 0), for: mockedScrollView3)
    scrollView.layoutViews()

    scrollView.contentOffset.y = 250
    scrollView.layoutViews()
    scrollView.layout()

    let lastSize = CGSize(width: 500, height: 220)

    XCTAssertEqual(mockedScrollView1.frame, CGRect(origin: CGPoint(x: 0, y: 0), size: size))
    XCTAssertEqual(mockedScrollView2.frame, CGRect(origin: CGPoint(x: 0, y: 250), size: size))
    XCTAssertEqual(mockedScrollView3.frame, CGRect(origin: CGPoint(x: 0, y: 500), size: size))
    XCTAssertEqual(mockedScrollView4.frame, CGRect(origin: CGPoint(x: 0, y: 750), size: lastSize))
    XCTAssertEqual(scrollView.documentView?.frame.size.height, 1000)

    scrollView.contentOffset.y = 500
    scrollView.layout()
    scrollView.layoutViews()

    XCTAssertEqual(mockedScrollView1.frame, CGRect(origin: CGPoint(x: 0, y: 0), size: size))
    XCTAssertEqual(mockedScrollView2.frame, CGRect(origin: CGPoint(x: 0, y: 250), size: size))
    XCTAssertEqual(mockedScrollView3.frame, CGRect(origin: CGPoint(x: 0, y: 500), size: size))
    XCTAssertEqual(mockedScrollView4.frame, CGRect(origin: CGPoint(x: 0, y: 750), size: lastSize))

    scrollView.contentOffset.y = 750
    scrollView.layoutViews()

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

