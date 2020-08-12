import UIKit
import Family_Shared

public extension UIViewController {
  /// A shorthand computed value to resolve the parent `FamilyViewController`.
  private var familyViewController: FamilyViewController? {
    guard let familyViewController = parent as? FamilyViewController else {
      assertionFailure("Controller must be added to a FamilyViewController before setting padding.")
      return nil
    }

    return familyViewController
  }

  /// A syntactic sugar to add backgrounds to view controller.
  ///
  /// - Parameter kind: The kind of background view that should be added.
  /// - Returns: Returns an instance of `Self`.
  @discardableResult
  func background(_ kind: BackgroundKind) -> Self {
    guard let familyViewController = familyViewController else {
        assertionFailure("Unable to find view controller.")
        return self
    }
    familyViewController.addBackground(kind, to: self)
    return self
  }

  /// A syntactic sugar to add padding to view controller.
  ///
  /// - Parameter insets: The amount of padding that should be used.
  /// - Returns: Returns an instance of `Self`.
  @discardableResult
  func padding(_ insets: UIEdgeInsets) -> Self {
    guard let familyViewController = familyViewController else {
      assertionFailure("Unable to find view controller.")
      return self
    }
    familyViewController.addPadding(insets, to: self)
    return self
  }

  /// A syntactic sugar to add margins to view controller.
  ///
  /// - Parameter insets: The amount of margins that should be used.
  /// - Returns: Returns an instance of `Self`.
  @discardableResult
  func margin(_ insets: UIEdgeInsets) -> Self {
    guard let familyViewController = familyViewController,
      let entry = familyViewController.registry[self] else {
      assertionFailure("Unable to find view controller.")
      return self
    }
    familyViewController.addMargins(insets, for: entry.view)
    return self
  }
}
