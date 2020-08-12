import CoreGraphics

public class FamilyCache: NSObject {
  public enum State {
    case empty, isRunning, isFinished
  }

  public var state: State = .empty
  public var contentSize: CGSize = .zero
  var storage = [View: FamilyViewControllerAttributes]()
  public var collection = [FamilyViewControllerAttributes]()
  public override init() {}

  public func add(entry: FamilyViewControllerAttributes) {
    storage[entry.view] = entry
    entry.previousAttributes = collection.last
    collection.append(entry)
    entry.previousAttributes?.nextAttributes = entry
  }

  public func entry(for view: View) -> FamilyViewControllerAttributes? {
    return storage[view]
  }

  public func invalidate() {
    storage.removeAll()
    collection.removeAll()
    state = .empty
  }
}
