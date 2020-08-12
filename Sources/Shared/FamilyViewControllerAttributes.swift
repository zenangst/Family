import CoreGraphics

public class FamilyViewControllerAttributes: NSObject {
  public let view: View
  public var origin: CGPoint
  public var contentSize: CGSize
  public var maxY: CGFloat
  public weak var nextAttributes: FamilyViewControllerAttributes?
  public weak var previousAttributes: FamilyViewControllerAttributes?
  public var frame: CGRect {
    return CGRect(origin: origin, size: contentSize)
  }
  public let scrollView: ScrollView

  public init?(view: View, origin: CGPoint, contentSize: CGSize, nextAttributes: FamilyViewControllerAttributes? = nil) {
    self.view = view
    self.origin = origin
    self.contentSize = contentSize
    self.maxY = round(contentSize.height + origin.y)
    self.nextAttributes = nextAttributes
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

  func updateWithAbsolute(_ absolute: CGFloat) {
    origin.y = absolute
    maxY = round(contentSize.height + origin.y)
  }
}
