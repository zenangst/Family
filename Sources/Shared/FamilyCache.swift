import CoreGraphics

class FamilyCache: NSObject {
  enum State {
    case empty, isRunning, isFinished
  }

  var state: State = .empty
  var contentSize: CGSize = .zero
  var storage = [View: FamilyViewControllerAttributes]()
  var collection = [FamilyViewControllerAttributes]()
  override init() {}

  func add(entry: FamilyViewControllerAttributes) {
    storage[entry.view] = entry
    entry.previousAttributes = collection.last
    collection.append(entry)
    entry.previousAttributes?.nextAttributes = entry
  }

  func entry(for view: View) -> FamilyViewControllerAttributes? {
    return storage[view]
  }

  func invalidate() {
    storage.removeAll()
    collection.removeAll()
    state = .empty
  }
}
