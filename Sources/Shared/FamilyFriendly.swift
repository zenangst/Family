import CoreGraphics
import Foundation

protocol FamilyFriendly: class {
  func addChild(_ childController: ViewController)
  func addChild<T: ViewController>(_ childController: T,
                                   at index: Int?,
                                   customInsets: Insets?,
                                   height: CGFloat?,
                                   view handler: ((T) -> View)?)
  func addChildren(_ childControllers: ViewController ...)
  func addView(_ subview: View,
               at index: Int?,
               customInsets insets: Insets?,
               withHeight height: CGFloat?)
  func moveChild(_ childController: ViewController, to index: Int)
  func performBatchUpdates(_ handler: (FamilyViewController) -> Void,
                           completion: ((FamilyViewController) -> Void)?)
  func purgeRemovedViews()
}
