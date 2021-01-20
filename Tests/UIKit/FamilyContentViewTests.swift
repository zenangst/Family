import XCTest
@testable import Family

#if canImport(UIKit)
class FamilyContentViewTests: XCTestCase {
  var scrollView: FamilyScrollView!

  override func setUp() {
    scrollView = FamilyScrollView()
  }

  func testAddingRegularViewToContentView() {
    let size = CGSize(width: 200, height: 200)
    let regularView = UIView(frame: CGRect(origin: .zero, size: size))

    scrollView.addSubview(regularView)

    guard let expectedView = scrollView.subviews[0] as? FamilyWrapperView else {
      XCTFail("Unable to resolve wrapper view.")
      return
    }

    XCTAssertEqual(expectedView.view, regularView)
    XCTAssertEqual(expectedView.frame.size, size)
    XCTAssertEqual(expectedView.contentSize, size)

    expectedView.removeFromSuperview()

    XCTAssertTrue(scrollView.subviews.isEmpty)
  }

  func testAddingScrollViewToContentView() {
    let size = CGSize(width: 200, height: 200)
    let scrollView = UIScrollView(frame: CGRect(origin: .zero, size: size))
    scrollView.contentSize = size

    self.scrollView.addSubview(scrollView)

    guard let expectedView = self.scrollView.subviews[0] as? UIScrollView else {
      XCTFail("Unable to resolve wrapper view.")
      return
    }

    XCTAssertEqual(expectedView, scrollView)
    XCTAssertEqual(expectedView.frame.size, size)
    XCTAssertEqual(expectedView.contentSize, size)

    expectedView.removeFromSuperview()

    XCTAssertTrue(scrollView.subviews.isEmpty)
  }
}
#endif
