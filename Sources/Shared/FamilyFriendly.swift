import CoreGraphics
import Foundation

protocol FamilyFriendly: class {
  var registry: [ViewController: View] { get set }

  func addChildViewController(_ childController: ViewController)
  func addChildViewController(_ childController: ViewController, height: CGFloat)
  func addChildViewController<T: ViewController>(_ childController: T, view closure: (T) -> View)
  func addChildViewControllers(_ childControllers: ViewController ...)

  func purgeRemovedViews()
}
