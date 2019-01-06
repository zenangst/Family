import CoreGraphics

public class FamilyViewControllerAttributes: NSObject {
  let view: View
  let origin: CGPoint
  let contentSize: CGSize
  let maxY: CGFloat

  init(view: View, origin: CGPoint, contentSize: CGSize) {
    self.view = view
    self.origin = origin
    self.contentSize = contentSize
    self.maxY = contentSize.height + origin.y
  }
}
