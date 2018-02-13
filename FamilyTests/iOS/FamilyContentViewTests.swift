import XCTest
@testable import Family

class FamilyContentViewTests: XCTestCase {
  var scrollView: FamilyScrollView!
  var contentView: FamilyContentView!

  override func setUp() {
    scrollView = FamilyScrollView()
    contentView = scrollView.contentView
  }

  func testAddingRegularViewToContentView() {
    let size = CGSize(width: 200, height: 200)
    let regularView = UIView(frame: CGRect(origin: .zero, size: size))

    contentView.addSubview(regularView)

    guard let expectedView = contentView.subviews[0] as? FamilyWrapperView else {
      XCTFail("Unable to resolve wrapper view.")
      return
    }

    XCTAssertEqual(expectedView.view, regularView)
    XCTAssertEqual(expectedView.frame.size, size)
    XCTAssertEqual(expectedView.contentSize, size)

    expectedView.removeFromSuperview()

    XCTAssertTrue(contentView.subviews.isEmpty)
  }

  func testAddingScrollViewToContentView() {
    let size = CGSize(width: 200, height: 200)
    let scrollView = UIScrollView(frame: CGRect(origin: .zero, size: size))
    scrollView.contentSize = size

    contentView.addSubview(scrollView)

    guard let expectedView = contentView.subviews[0] as? UIScrollView else {
      XCTFail("Unable to resolve wrapper view.")
      return
    }

    XCTAssertEqual(expectedView, scrollView)
    XCTAssertEqual(expectedView.frame.size, size)
    XCTAssertEqual(expectedView.contentSize, size)

    expectedView.removeFromSuperview()

    XCTAssertTrue(contentView.subviews.isEmpty)
  }
}
