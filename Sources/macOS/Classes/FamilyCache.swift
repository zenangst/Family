import Cocoa

class FamilyCache: NSObject {
  var contentSize: CGSize = .zero
  var storage = [NSView: FamilyCacheEntry]()
  var isEmpty: Bool { return storage.isEmpty }
  override init() {}

  func add(entry: FamilyCacheEntry) {
    storage[entry.view] = entry
  }

  func entry(for view: NSView) -> FamilyCacheEntry? {
    return storage[view]
  }

  func clear() {
    storage.removeAll()
  }
}
