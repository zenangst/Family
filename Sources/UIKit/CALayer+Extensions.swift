#if canImport(UIKit)
import UIKit

extension CALayer {
  /// Returns all animations that have keys.
  var allAnimationsWithKeys: [CAAnimation] {
    var animations = [CAAnimation]()
    guard let keys = animationKeys() else { return animations }
    for key in keys {
      if let animation = self.animation(forKey: key) {
        animations.append(animation)
      }
    }
    return animations
  }

  /// Resolve first animation matching type.
  ///
  /// - Parameter animationType: The type of CAAnimation that should be resolved.
  /// - Returns: The first CAAnimation that matches the type.
  func animation<T: CAAnimation>(_ animationType: T.Type) -> T? {
    return allAnimationsWithKeys.compactMap({ $0 as? T }).first
  }

  /// Resolve animation duration of the first animation using animation keys.
  var resolveAnimationDuration: CFTimeInterval? {
    if let firstKey = animationKeys()?.first,
      let animation = animation(forKey: firstKey) {
      return animation.duration
    }

    return nil
  }
}
#endif
