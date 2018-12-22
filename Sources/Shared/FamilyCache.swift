import CoreGraphics

class FamilyCache: NSObject {
  enum State {
    case empty, isRunning, isFinished
  }

  var state: State = .empty
  var contentSize: CGSize = .zero
  var storage = [View: FamilyCacheEntry]()
  override init() {}

  func add(entry: FamilyCacheEntry) {
    storage[entry.view] = entry
  }

  func entry(for view: View) -> FamilyCacheEntry? {
    return storage[view]
  }

  func invalidate() {
    storage.removeAll()
    state = .empty
  }
}
