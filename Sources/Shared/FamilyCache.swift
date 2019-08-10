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
    collection.append(entry)
    collection.sort(by: { $0.frame.maxY < $1.frame.maxY })
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
