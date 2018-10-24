import XCTest
@testable import Family

class FamilyContentViewTests: XCTestCase {
  class FamilyScrollViewMock: FamilyScrollView {
    var didLayout: Bool = false
    override func layoutViews(withDuration duration: CFTimeInterval? = nil,
                              excludeOffscreenViews: Bool = true) {
      super.layoutViews(
        withDuration: duration,
        excludeOffscreenViews: excludeOffscreenViews
      )
      didLayout = true
    }
  }

  var scrollView: FamilyScrollViewMock!
  var contentView: FamilyContentView!

  override func setUp() {
    scrollView = FamilyScrollViewMock()
    contentView = scrollView.documentView as! FamilyContentView
  }

  func testAddingRegularViewToContentView() {
    let size = CGSize(width: 200, height: 200)
    scrollView.frame.size = size
    let regularView = NSView(frame: CGRect(origin: .zero, size: size))

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
    let scrollView = NSScrollView(frame: CGRect(origin: .zero, size: size))

    contentView.addSubview(scrollView)

    guard let expectedView = contentView.subviews[0] as? NSScrollView else {
      XCTFail("Unable to resolve wrapper view.")
      return
    }

    XCTAssertEqual(expectedView, scrollView)
    XCTAssertEqual(expectedView.frame.size, size)
    XCTAssertEqual(expectedView.contentSize, size)

    expectedView.removeFromSuperview()

    XCTAssertTrue(contentView.subviews.isEmpty)
  }

  func testLayoutMethod() {
    let size = CGSize(width: 200, height: 200)
    let view = NSView(frame: CGRect(origin: .zero, size: size))
    XCTAssertFalse(scrollView.didLayout)
    contentView.addSubview(view)
    XCTAssertTrue(scrollView.didLayout)
  }
}
