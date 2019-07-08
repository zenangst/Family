import CoreGraphics

class FamilySpaceManager {
  /// A dictionary of the views and what margins they should use.
  private var margins = [View: Insets]()
  /// A dictionary of the views and what padding they should use.
  private var padding = [View: Insets]()
  /// The insets used between views.
  var defaultMargins: Insets = .init(top: 0, left: 0, bottom: 0, right: 0)
  var defaultPadding: Insets = .init(top: 0, left: 0, bottom: 0, right: 0)

  /// Get margins for the view, if the view does not have custom insets
  /// then the general spacing will be returned.
  ///
  /// - Parameter view: The view that should be used to resolve the value.
  /// - Returns: The amount of insets that should appear after the view, either
  ///            custom insets or the general insets.
  func margins(for view: View) -> Insets {
    let targetView = (view as? FamilyWrapperView)?.view ?? view
    return margins[targetView] ?? defaultMargins
  }

  /// Get padding for the view, if the view does not have custom insets
  /// then the general spacing will be returned.
  ///
  /// - Parameter view: The view that should be used to resolve the value.
  /// - Returns: The amount of insets that should appear after the view, either
  ///            custom insets or the general insets.
  func padding(for view: View) -> Insets {
    let targetView = (view as? FamilyWrapperView)?.view ?? view
    return padding[targetView] ?? defaultPadding
  }

  /// Set margins for view.
  ///
  /// - Parameters:
  ///   - insets: The insets that should be added after the view.
  ///   - view: The view that should get custom insets for the view.
  func addMargins(_ insets: Insets, for view: View) {
    margins[view] = insets
  }

  /// Set padding for view.
  ///
  /// - Parameters:
  ///   - insets: The insets that should be added after the view.
  ///   - view: The view that should get custom insets for the view.
  func addPadding(_ insets: Insets, for view: View) {
    padding[view] = insets
  }

  /// Remove view from registry.
  ///
  /// - Parameter view: The view that should be removed from the registry.
  func removeView(_ view: View) {
    margins.removeValue(forKey: view)
    padding.removeValue(forKey: view)
  }

  /// Remove all views, both from the heirarcy and the registry.
  func removeAll() {
    margins.forEach { $0.key.removeFromSuperview() }
    margins.removeAll()
    padding.forEach { $0.key.removeFromSuperview() }
    padding.removeAll()
  }

  func removeViewsWithoutSuperview() {
    for (view, _) in margins where view.superview == nil {
      removeView(view)
    }

    for (view, _) in padding where view.superview == nil {
      removeView(view)
    }
  }
}
