import CoreGraphics
import Foundation

protocol FamilyFriendly: class {
  func addChildViewController(_ childController: ViewController)
  func addChildViewController(_ childController: ViewController, customSpacing: CGFloat?, height: CGFloat)
  func addChildViewController<T: ViewController>(_ childController: T, customSpacing: CGFloat?, view closure: (T) -> View)
  func addChildViewControllers(_ childControllers: ViewController ...)

  func purgeRemovedViews()
}
