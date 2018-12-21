import CoreGraphics
import Foundation

protocol FamilyFriendly: class {
  func addChild(_ childController: ViewController)
  func addChild(_ childController: ViewController, at index: Int?, customInsets: Insets?, height: CGFloat)
  func addChild<T: ViewController>(_ childController: T, at index: Int?, customInsets: Insets?, view closure: (T) -> View)
  func addChildren(_ childControllers: ViewController ...)

  func performBatchUpdates(_ handler: (FamilyViewController) -> Void,
                           completion: ((FamilyViewController) -> Void)?)

  func purgeRemovedViews()
}
