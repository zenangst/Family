import XCTest
@testable import Family

class FamilyContentViewTests: XCTestCase {
  var scrollView: FamilyScrollView!
  var documentView: FamilyDocumentView!

  override func setUp() {
    scrollView = FamilyScrollView()
    documentView = scrollView.documentView
  }

  func testAddingRegularViewToContentView() {
    let size = CGSize(width: 200, height: 200)
    let regularView = UIView(frame: CGRect(origin: .zero, size: size))

    documentView.addSubview(regularView)

    guard let expectedView = documentView.subviews[0] as? FamilyWrapperView else {
      XCTFail("Unable to resolve wrapper view.")
      return
    }

    XCTAssertEqual(expectedView.view, regularView)
    XCTAssertEqual(expectedView.frame.size, size)
    XCTAssertEqual(expectedView.contentSize, size)

    expectedView.removeFromSuperview()

    XCTAssertTrue(documentView.subviews.isEmpty)
  }

  func testAddingScrollViewToContentView() {
    let size = CGSize(width: 200, height: 200)
    let scrollView = UIScrollView(frame: CGRect(origin: .zero, size: size))
    scrollView.contentSize = size

    documentView.addSubview(scrollView)

    guard let expectedView = documentView.subviews[0] as? UIScrollView else {
      XCTFail("Unable to resolve wrapper view.")
      return
    }

    XCTAssertEqual(expectedView, scrollView)
    XCTAssertEqual(expectedView.frame.size, size)
    XCTAssertEqual(expectedView.contentSize, size)

    expectedView.removeFromSuperview()

    XCTAssertTrue(documentView.subviews.isEmpty)
  }
}
