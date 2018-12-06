import CoreGraphics

class FamilyCacheEntry: NSObject {
  var view: View
  var origin: CGPoint
  var contentSize: CGSize
  var maxY: CGFloat

  init(view: View, origin: CGPoint, contentSize: CGSize) {
    self.view = view
    self.origin = origin
    self.contentSize = contentSize
    self.maxY = contentSize.height + origin.y
  }
}
