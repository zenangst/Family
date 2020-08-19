import XCTest
@testable import Family_macOS

class NSScrollViewExtensionsTests: XCTestCase {
  func testInitializer() {
    let documentView = NSView()
    let scrollView = NSScrollView(documentView: documentView)

    XCTAssertEqual(documentView, scrollView.documentView)
  }
}
