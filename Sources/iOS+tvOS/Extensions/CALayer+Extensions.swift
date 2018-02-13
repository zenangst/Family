import UIKit

extension CALayer {
  /// Resolve animation duration of the first animation using animation keys.
  var resolveAnimationDuration: CFTimeInterval? {
    if let firstKey = animationKeys()?.first,
      let animation = animation(forKey: firstKey) {
      return animation.duration
    }

    return nil
  }
}
