import CoreGraphics

class FamilySpaceManager {
  /// A dictionary of the views and what custom insets they should use.
  private var registry = [View: Insets]()
  /// The isnets used between views.
  var insets: Insets = .init(top: 0, left: 0, bottom: 0, right: 0)

  /// Get custom insets for the view, if the view does not have custom insets
  /// then the general spacing will be returned.
  ///
  /// - Parameter view: The view that should be used to resolve the value.
  /// - Returns: The amount of insets that should appear after the view, either
  ///            custom insets or the general insets.
  func customInsets(for view: View) -> Insets {
    if let value = registry[view] {
      return value
    } else {
      return insets
    }
  }

  /// Set custom insets for view.
  ///
  /// - Parameters:
  ///   - insets: The insets that should be added after the view.
  ///   - view: The view that should get custom insets for the view.
  func setCustomInsets(_ insets: Insets, for view: View) {
    registry[view] = insets
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

  func removeViewsWithoutSuperview() {
    for (view, _) in registry where view.superview == nil {
      removeView(view)
    }
  }
}
