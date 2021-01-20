import XCTest
@testable import Family

#if canImport(Cocoa)
class NSScrollViewExtensionsTests: XCTestCase {
  func testInitializer() {
    let documentView = NSView()
    let scrollView = NSScrollView(documentView: documentView)

    XCTAssertEqual(documentView, scrollView.documentView)
  }
}
#endif
