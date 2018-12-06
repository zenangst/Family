import CoreGraphics
import Foundation

protocol FamilyFriendly: class {
  func addChild(_ childController: ViewController)
  func addChild(_ childController: ViewController, customInsets: Insets?, height: CGFloat)
  func addChild<T: ViewController>(_ childController: T, customInsets: Insets?, view closure: (T) -> View)
  func addChildren(_ childControllers: ViewController ...)

  func purgeRemovedViews()
}
