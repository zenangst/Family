import XCTest
@testable import Family

#if canImport(UIKit)
class FamilyScrollViewTests: XCTestCase {
  static let mockFrame = CGRect(origin: .zero, size: CGSize(width: 500, height: 1000))
  let superview = UIView(frame: FamilyScrollViewTests.mockFrame)
  var scrollView: FamilyScrollView!

  override func setUp() {
    super.setUp()
    scrollView = FamilyScrollView()
  }

  override func tearDown() {
    super.tearDown()
    superview.subviews.forEach { $0.removeFromSuperview() }
  }

  func testContentSizeObserver() {
    scrollView.frame.size.width = FamilyScrollViewTests.mockFrame.size.width
    superview.addSubview(scrollView)
    var size = CGSize(width: 500, height: 250)
    let mockedScrollView = UIScrollView(frame: CGRect(origin: .zero, size: size))
    mockedScrollView.contentSize = size

    scrollView.frame.size.height = 1500
    scrollView.addSubview(mockedScrollView)
    scrollView.layoutViews()

    XCTAssertEqual(mockedScrollView.frame, CGRect(origin: .zero, size: size))

    // Check that the layout algorithm is invoked if the views frame changes.
    size.height = 1500
    mockedScrollView.contentSize = size
    XCTAssertEqual(scrollView.contentSize, size)
  }

  func testCollectionViews() {
    let frame = CGRect(origin: .zero, size: CGSize(width: 500, height: 200))
    let verticalCollectionViewLayout = UICollectionViewFlowLayout()
    verticalCollectionViewLayout.scrollDirection = .vertical
    let verticalCollectionView = UICollectionView(frame: frame, collectionViewLayout: verticalCollectionViewLayout)
    scrollView.addSubview(verticalCollectionView)

    let horizontalCollectionViewLayout = UICollectionViewFlowLayout()
    horizontalCollectionViewLayout.scrollDirection = .horizontal
    let horizontalCollectionView = UICollectionView(frame: frame, collectionViewLayout: horizontalCollectionViewLayout)
    scrollView.addSubview(horizontalCollectionView)

    XCTAssertFalse(verticalCollectionView.isScrollEnabled)
    XCTAssertTrue(horizontalCollectionView.isScrollEnabled)

    horizontalCollectionView.removeFromSuperview()
    XCTAssertFalse(verticalCollectionView.isScrollEnabled)
  }

  func testTableViews() {
    let frame = CGRect(origin: .zero, size: CGSize(width: 500, height: 200))
    let tableView = UITableView(frame: frame)
    scrollView.addSubview(tableView)

    let anotherTableView = UITableView(frame: frame)
    scrollView.addSubview(anotherTableView)

    XCTAssertFalse(tableView.isScrollEnabled)
    XCTAssertFalse(anotherTableView.isScrollEnabled)

    anotherTableView.removeFromSuperview()
    XCTAssertFalse(tableView.isScrollEnabled)
  }

  func testLayoutAlgorithm() {
    scrollView.frame.size.width = FamilyScrollViewTests.mockFrame.size.width
    superview.addSubview(scrollView)

    XCTAssertEqual(scrollView.contentSize, .zero)
    // Should set the same height as the super view.
    XCTAssertEqual(superview.bounds, scrollView.frame)

    let size = CGSize(width: 500, height: 250)
    let mockedScrollView1 = UIScrollView(frame: CGRect(origin: .zero, size: size))
    let mockedScrollView2 = UIScrollView(frame: CGRect(origin: .zero, size: size))
    let mockedScrollView3 = UIScrollView(frame: CGRect(origin: .zero, size: size))
    let mockedScrollView4 = UIScrollView(frame: CGRect(origin: .zero, size: size))

    [mockedScrollView1, mockedScrollView2, mockedScrollView3, mockedScrollView4].forEach {
      $0.contentSize = size
      scrollView.addSubview($0)
    }

    scrollView.layoutViews()

    XCTAssertEqual(mockedScrollView1.frame, CGRect(origin: .zero, size: size))
    XCTAssertEqual(mockedScrollView2.frame, CGRect(origin: CGPoint(x: 0, y: 250), size: size))
    XCTAssertEqual(mockedScrollView3.frame, CGRect(origin: CGPoint(x: 0, y: 500), size: size))
    XCTAssertEqual(mockedScrollView4.frame, CGRect(origin: CGPoint(x: 0, y: 750), size: size))
    XCTAssertEqual(scrollView.contentSize.height, 1000)

    // Check that layout algorithm takes spacing between views into account.
    scrollView.margins = .init(top: 0, left: 0, bottom: 10, right: 0)
    scrollView.layoutSubviews()

    XCTAssertEqual(mockedScrollView1.frame, CGRect(origin: .zero, size: size))
    XCTAssertEqual(mockedScrollView2.frame, CGRect(origin: CGPoint(x: 0, y: 250 + scrollView.margins.bottom), size: size))
    XCTAssertEqual(mockedScrollView3.frame, CGRect(origin: CGPoint(x: 0, y: 500 + scrollView.margins.bottom * 2), size: size))
    XCTAssertEqual(mockedScrollView4.frame, CGRect(origin: CGPoint(x: 0, y: 750 + scrollView.margins.bottom * 3),
                                                   size: CGSize(width: size.width, height: size.height)))

    XCTAssertEqual(scrollView.contentSize.height, 1040)

    scrollView.margins = .zero
    scrollView.addMargins(.init(top: 0, left: 0, bottom: 10, right: 0), for: mockedScrollView1)
    scrollView.addMargins(.init(top: 0, left: 0, bottom: 10, right: 0), for: mockedScrollView3)
    scrollView.layoutSubviews()

    XCTAssertEqual(mockedScrollView1.frame, CGRect(origin: .zero, size: size))
    XCTAssertEqual(mockedScrollView2.frame, CGRect(origin: CGPoint(x: 0, y: 250 + 10), size: size))
    XCTAssertEqual(mockedScrollView3.frame, CGRect(origin: CGPoint(x: 0, y: 500 + 10), size: size))
    XCTAssertEqual(mockedScrollView4.frame, CGRect(origin: CGPoint(x: 0, y: 750 + 20),
                                                   size: CGSize(width: size.width, height: size.height)))
    XCTAssertEqual(scrollView.contentSize.height, 1020)

    scrollView.addMargins(.init(top: 0, left: 0, bottom: 0, right: 0), for: mockedScrollView1)
    scrollView.addMargins(.init(top: 0, left: 0, bottom: 0, right: 0), for: mockedScrollView3)

    scrollView.setContentOffset(CGPoint(x: 0, y: 250), animated: false)
    scrollView.layoutSubviews()

    XCTAssertEqual(mockedScrollView1.frame, CGRect(origin: CGPoint(x: 0, y: 0), size: size))
    XCTAssertEqual(mockedScrollView2.frame, CGRect(origin: CGPoint(x: 0, y: 250), size: size))
    XCTAssertEqual(mockedScrollView3.frame, CGRect(origin: CGPoint(x: 0, y: 500), size: size))
    XCTAssertEqual(mockedScrollView4.frame, CGRect(origin: CGPoint(x: 0, y: 750), size: size))
    XCTAssertEqual(scrollView.contentSize.height, 1000)

    scrollView.setContentOffset(CGPoint(x: 0, y: 500), animated: false)
    scrollView.layoutViews()

    XCTAssertEqual(mockedScrollView1.frame, CGRect(origin: CGPoint(x: 0, y: 0), size: size))
    XCTAssertEqual(mockedScrollView1.frame, CGRect(origin: CGPoint(x: 0, y: 0), size: size))
    XCTAssertEqual(mockedScrollView3.frame, CGRect(origin: CGPoint(x: 0, y: 500), size: size))
    XCTAssertEqual(mockedScrollView4.frame, CGRect(origin: CGPoint(x: 0, y: 750), size: size))

    scrollView.setContentOffset(CGPoint(x: 0, y: 750), animated: false)
    scrollView.layoutViews()

    XCTAssertEqual(mockedScrollView1.frame, CGRect(origin: CGPoint(x: 0, y: 0), size: size))
    XCTAssertEqual(mockedScrollView1.frame, CGRect(origin: CGPoint(x: 0, y: 0), size: size))
    XCTAssertEqual(mockedScrollView1.frame, CGRect(origin: CGPoint(x: 0, y: 0), size: size))
    XCTAssertEqual(mockedScrollView4.frame, CGRect(origin: CGPoint(x: 0, y: 750), size: size))
  }
}
#endif
