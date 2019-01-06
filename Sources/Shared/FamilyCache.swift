import CoreGraphics

class FamilyCache: NSObject {
  enum State {
    case empty, isRunning, isFinished
  }

  var state: State = .empty
  var contentSize: CGSize = .zero
  var storage = [View: FamilyViewControllerAttributes]()
  override init() {}

  func add(entry: FamilyViewControllerAttributes) {
    storage[entry.view] = entry
  }

  func entry(for view: View) -> FamilyViewControllerAttributes? {
    return storage[view]
  }

  func invalidate() {
    storage.removeAll()
    state = .empty
  }
}
