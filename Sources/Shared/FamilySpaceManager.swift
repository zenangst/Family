import CoreGraphics

class FamilySpaceManager {
  /// A dictionary of the views and what custom spacing they should use.
  private var registry = [View: CGFloat]()
  /// The spacing used between views.
  var spacing: CGFloat = 0

  /// Get custom spacing for the view, if the view does not have custom spacing
  /// then the general spacing will be returned.
  ///
  /// - Parameter view: The view that should be used to resolve the value.
  /// - Returns: The amount of spacing that should appear after the view, either
  ///            custom spacing or the general spacing.
  func customSpacing(after view: View) -> CGFloat {
    if let value = registry[view] {
      return value
    } else {
      return spacing
    }
  }

  /// Set custom spacing after view.
  ///
  /// - Parameters:
  ///   - spacing: The spacing that should be added after the view.
  ///   - view: The view that should get custom spacing after the view.
  func setCustomSpacing(_ spacing: CGFloat, after view: View) {
    registry[view] = spacing
  }

  /// Remove view from registry.
  ///
  /// - Parameter view: The view that should be removed from the registry.
  func removeView(_ view: View) {
    registry.removeValue(forKey: view)
  }

  /// Remove all views, both from the heirarcy and the registry.
  func removeAll() {
    registry.forEach { $0.key.removeFromSuperview() }
    registry.removeAll()
  }
}
