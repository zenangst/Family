import XCTest
@testable import Family_macOS

class FamilyWrapperViewTests: XCTestCase {
  class MockMouseWheelEvent: NSEvent {
    enum Direction {
      case horizontal, vertical

      var x: CGFloat {
        switch self {
        case .horizontal:
          return 1.0
        case .vertical:
          return 0.0
        }
      }

      var y: CGFloat {
        switch self {
        case .horizontal:
          return 0.0
        case .vertical:
          return -1.0
        }
      }
    }

    var direction: Direction
    override var phase: NSEvent.Phase { return .changed }
    override var subtype: NSEvent.EventSubtype { return .tabletPoint }
    override var scrollingDeltaY: CGFloat { return direction.y }
    override var scrollingDeltaX: CGFloat { return direction.x }
    override var type: NSEvent.EventType { return .scrollWheel }
    override var cgEvent: CGEvent? {
      return CGEvent(
        mouseEventSource: nil,
        mouseType: .scrollWheel,
        mouseCursorPosition: .zero,
        mouseButton: .center
      )
    }

    @objc var _scrollCount: Int { return 1 }

    required init(direction: Direction) {
      self.direction = direction
      super.init()
    }

    required init?(coder aDecoder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }
  }

  class MockScrollView: NSScrollView {
    var didScroll: Bool = false
    override func scrollWheel(with event: NSEvent) {
      didScroll = true
    }
  }

  func testFamilyWrapperViewWithVerticalScrolling() {
    let frame = CGRect(origin: .zero,
                       size: CGSize(width: 200, height: 200))
    let mockedScrollView = MockScrollView(frame: frame)
    let view = NSView(frame: frame)
    let wrapper = FamilyWrapperView(frame: frame, wrappedView: view)
    mockedScrollView.addSubview(wrapper)

    XCTAssertEqual(wrapper.view, view)
    XCTAssertNil(wrapper.verticalScroller)
    XCTAssertFalse(mockedScrollView.didScroll)

    wrapper.scrollWheel(with: MockMouseWheelEvent(direction: .vertical))
    XCTAssertTrue(mockedScrollView.didScroll)
  }

  func testFamilyWrapperViewScroller() {
    let scroller = NSScroller()
    let frame = CGRect(origin: .zero,
                       size: CGSize(width: 200, height: 200))
    let view = NSView(frame: frame)
    let wrapper = FamilyWrapperView(frame: frame, wrappedView: view)

    XCTAssertNil(wrapper.verticalScroller)
    wrapper.verticalScroller = scroller
    XCTAssertNil(wrapper.verticalScroller)
  }

//  func testFamilyWrapperViewWithHorizontalScrolling() {
//    let frame = CGRect(origin: .zero,
//                       size: CGSize(width: 200, height: 200))
//    let mockedScrollView = MockScrollView(frame: frame)
//    let view = NSView(frame: frame)
//    let wrapper = FamilyWrapperView(frame: frame, wrappedView: view)
//    mockedScrollView.addSubview(wrapper)
//
//    XCTAssertEqual(wrapper.wrappedView, view)
//    XCTAssertNil(wrapper.verticalScroller)
//    XCTAssertFalse(mockedScrollView.didScroll)
//
//    view.frame.size.width = 400
//    wrapper.scrollWheel(with: MockMouseWheelEvent(direction: .horizontal))
//    XCTAssertFalse(mockedScrollView.didScroll)
//  }
}
