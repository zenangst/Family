import CoreGraphics

/// Describes a view that wrappes an other
public protocol ViewWrapper {
    var view: View { get }
}

public class FamilySpaceManager {
  /// A dictionary of the views and what margins they should use.
  private var margins = [View: Insets]()
  /// A dictionary of the views and what padding they should use.
  private var padding = [View: Insets]()
  /// The insets used between views.
  public var defaultMargins: Insets = .init(top: 0, left: 0, bottom: 0, right: 0)
  public var defaultPadding: Insets = .init(top: 0, left: 0, bottom: 0, right: 0)

  public init() {}

  /// Get margins for the view, if the view does not have custom insets
  /// then the general spacing will be returned.
  ///
  /// - Parameter view: The view that should be used to resolve the value.
  /// - Returns: The amount of insets that should appear after the view, either
  ///            custom insets or the general insets.
  public func margins(for view: View) -> Insets {
    let targetView = (view as? ViewWrapper)?.view ?? view
    return margins[targetView] ?? defaultMargins
  }

  /// Get margins for the attributes, if the view does not have custom insets
  /// then the general spacing will be returned.
  ///
  /// - Parameter attributes: The attributes for a view controller.
  /// - Returns: The amount of insets that should appear after the view, either
  ///            custom insets or the general insets.
  func margins(for attributes: FamilyViewControllerAttributes) -> Insets {
    return margins[attributes.view] ?? defaultMargins
  }

  /// Get padding for the view, if the view does not have custom insets
  /// then the general spacing will be returned.
  ///
  /// - Parameter view: The view that should be used to resolve the value.
  /// - Returns: The amount of insets that should appear after the view, either
  ///            custom insets or the general insets.
  public func padding(for view: View) -> Insets {
    let targetView = (view as? ViewWrapper)?.view ?? view
    return padding[targetView] ?? defaultPadding
  }

  /// Get padding for the attributes, if the view does not have custom insets
  /// then the general spacing will be returned.
  ///
  /// - Parameter attributes: The attributes for a view controller.
  /// - Returns: The amount of insets that should appear after the view, either
  ///            custom insets or the general insets.
  func padding(for attributes: FamilyViewControllerAttributes) -> Insets {
    return padding[attributes.view] ?? defaultPadding
  }

  /// Set margins for view.
  ///
  /// - Parameters:
  ///   - insets: The insets that should be added after the view.
  ///   - view: The view that should get custom insets for the view.
  public func addMargins(_ insets: Insets, for view: View) {
    margins[view] = insets
  }

  /// Set padding for view.
  ///
  /// - Parameters:
  ///   - insets: The insets that should be added after the view.
  ///   - view: The view that should get custom insets for the view.
  public func addPadding(_ insets: Insets, for view: View) {
    padding[view] = insets
  }

  /// Remove view from registry.
  ///
  /// - Parameter view: The view that should be removed from the registry.
  public func removeView(_ view: View) {
    margins.removeValue(forKey: view)
    padding.removeValue(forKey: view)
  }

  /// Remove all views, both from the heirarcy and the registry.
  public func removeAll() {
    margins.forEach { $0.key.removeFromSuperview() }
    margins.removeAll()
    padding.forEach { $0.key.removeFromSuperview() }
    padding.removeAll()
  }

  public func removeViewsWithoutSuperview() {
    for (view, _) in margins where view.superview == nil {
      removeView(view)
    }

    for (view, _) in padding where view.superview == nil {
      removeView(view)
    }
  }
}
