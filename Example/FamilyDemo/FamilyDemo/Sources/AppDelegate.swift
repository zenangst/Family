import UIKit
import Family_Mobile

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

  var window: UIWindow?

  lazy var navigationController: UINavigationController = { [unowned self] in
    let controller = UINavigationController(rootViewController: self.viewController)
    return controller
    }()

  lazy var viewController: ContainerController = ContainerController()

  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    Bundle(path: "/Applications/InjectionIII.app/Contents/Resources/iOSInjection.bundle")?.load()
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(loadApplication),
      name: NSNotification.Name(rawValue: "INJECTION_BUNDLE_NOTIFICATION"),
      object: nil
    )
    loadApplication()
    return true
  }

  @objc func loadApplication() {
    window = UIWindow(frame: UIScreen.main.bounds)
    window?.rootViewController = navigationController
    window?.makeKeyAndVisible()
  }
}
