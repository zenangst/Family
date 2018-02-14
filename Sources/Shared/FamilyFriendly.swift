import CoreGraphics

protocol FamilyFriendly: class {
  func addChildViewController(_ childController: ViewController)
  func addChildViewController(_ childController: ViewController, height: CGFloat)
  func addChildViewController<T: ViewController>(_ childController: T, view closure: (T) -> View)
}
