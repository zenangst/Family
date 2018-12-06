import CoreGraphics

class FamilyCache: NSObject {
  var contentSize: CGSize = .zero
  var storage = [View: FamilyCacheEntry]()
  var isEmpty: Bool { return storage.isEmpty }
  override init() {}

  func add(entry: FamilyCacheEntry) {
    storage[entry.view] = entry
  }

  func entry(for view: View) -> FamilyCacheEntry? {
    return storage[view]
  }

  func clear() {
    storage.removeAll()
  }
}
