import CoreGraphics

public class FamilyViewControllerAttributes: NSObject {
  public let view: View
  public let origin: CGPoint
  public let contentSize: CGSize
  public let maxY: CGFloat
  public var frame: CGRect {
    return CGRect(origin: origin, size: contentSize)
  }
  public let scrollView: ScrollView

  init?(view: View, origin: CGPoint, contentSize: CGSize) {
    self.view = view
    self.origin = origin
    self.contentSize = contentSize
    self.maxY = round(contentSize.height + origin.y)
    #if os(macOS)
    self.scrollView = view.enclosingScrollView!
    #else
    if let scrollView = view.superview as? ScrollView {
      self.scrollView = (view as? ScrollView) ?? scrollView
    } else {
      return nil
    }
    #endif

  }
}
