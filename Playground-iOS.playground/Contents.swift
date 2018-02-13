import UIKit
import Family
import PlaygroundSupport

let frame = CGRect(origin: .zero, size: CGSize(width: 320, height: 640))
let window = UIWindow(frame: frame)
let familyViewController = FamilyViewController()
familyViewController.view.frame = window.bounds
familyViewController.view.backgroundColor = .white

let redViewController = UIViewController()
redViewController.view.backgroundColor = UIColor.red.withAlphaComponent(0.2)

let blueViewController = UIViewController()
blueViewController.view.backgroundColor = UIColor.blue.withAlphaComponent(0.2)

let greenViewController = UIViewController()
greenViewController.view.backgroundColor = UIColor.green.withAlphaComponent(0.2)

let yellowViewController = UIViewController()
yellowViewController.view.backgroundColor = UIColor.yellow.withAlphaComponent(0.2)

familyViewController.addChildViewController(blueViewController, height: 200)
familyViewController.addChildViewController(redViewController, height: 200)
familyViewController.addChildViewController(greenViewController, height: 200)
familyViewController.addChildViewController(yellowViewController, height: 200)

window.rootViewController = familyViewController

PlaygroundPage.current.liveView = familyViewController
PlaygroundPage.current.needsIndefiniteExecution = true


