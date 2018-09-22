import CoreGraphics
import Foundation

protocol FamilyFriendly: class {
  func addChild(_ childController: ViewController)
  func addChild(_ childController: ViewController, customSpacing: CGFloat?, height: CGFloat)
  func addChild<T: ViewController>(_ childController: T, customSpacing: CGFloat?, view closure: (T) -> View)
  func addChildren(_ childControllers: ViewController ...)

  func purgeRemovedViews()
}
