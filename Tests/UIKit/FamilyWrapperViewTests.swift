import XCTest
@testable import Family

#if canImport(UIKit)
class FamilyWrapperViewTests: XCTestCase {
  func testFamilyWrapperView() {
    let frame = CGRect(origin: .zero, size: CGSize(width: 100, height: 100))
    let mockedView = UIView(frame: frame)
    let wrapperView = FamilyWrapperView(frame: .zero, view: mockedView)

    // Check that the wrapper views frame is equal to the wrapped view.
    XCTAssertEqual(wrapperView.frame, mockedView.frame)

    // Check that if the views frame change, the wrapper should get the same size.
    mockedView.frame.size = CGSize(width: 200, height: 200)
    XCTAssertEqual(wrapperView.contentSize, mockedView.frame.size)
    XCTAssertEqual(wrapperView.frame, mockedView.frame)
  }
}
#endif
