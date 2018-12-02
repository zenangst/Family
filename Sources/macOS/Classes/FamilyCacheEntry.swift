import Cocoa

class FamilyCacheEntry: NSObject {
  var view: NSView
  var origin: CGPoint
  var contentSize: CGSize

  init(view: NSView, origin: CGPoint, contentSize: CGSize) {
    self.view = view
    self.origin = origin
    self.contentSize = contentSize
  }
}
