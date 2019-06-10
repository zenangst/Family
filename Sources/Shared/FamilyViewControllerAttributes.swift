import CoreGraphics

public class FamilyViewControllerAttributes: NSObject {
  public let view: View
  public let origin: CGPoint
  public let contentSize: CGSize
  public let maxY: CGFloat

  init(view: View, origin: CGPoint, contentSize: CGSize) {
    self.view = view
    self.origin = origin
    self.contentSize = contentSize
    self.maxY = contentSize.height + origin.y
  }
}
