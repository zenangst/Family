import XCTest
@testable import Family

#if canImport(Cocoa)

class FamilyContentViewTests: XCTestCase {
  class FamilyScrollViewMock: FamilyScrollView {
    var didLayout: Bool = false

    init() {
      super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    override func layoutViews(withDuration duration: CFTimeInterval?,
                              allowsImplicitAnimation: Bool,
                              force: Bool,
                              completion: (() -> Void)?) {
      super.layoutViews(
        withDuration: duration,
        allowsImplicitAnimation: true,
        force: force,
        completion: nil
      )
      didLayout = true
    }
  }

  var scrollView: FamilyScrollViewMock!
  var contentView: FamilyDocumentView!

  override func setUp() {
    scrollView = FamilyScrollViewMock()
    contentView = scrollView.documentView as? FamilyDocumentView
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
#endif
