import Cocoa
import Family
import PlaygroundSupport

class CodeViewController: NSViewController {
  override func loadView() {
    let view = NSView()
    view.autoresizingMask = NSView.AutoresizingMask.width
    view.autoresizesSubviews = true
    view.wantsLayer = true
    self.view = view
  }
}

let frame = NSRect(origin: .zero, size: CGSize(width: 320, height: 640))
let familyViewController = FamilyViewController.init(nibName: nil, bundle: nil)
let blueViewController = CodeViewController.init(nibName: nil, bundle: nil)
let redViewController = CodeViewController.init(nibName: nil, bundle: nil)
let greenViewController = CodeViewController.init(nibName: nil, bundle: nil)
let yellowViewController = CodeViewController.init(nibName: nil, bundle: nil)

familyViewController.view.setFrameSize(frame.size)

blueViewController.view.layer?.backgroundColor = NSColor.blue.withAlphaComponent(0.2).cgColor
redViewController.view.layer?.backgroundColor = NSColor.red.withAlphaComponent(0.2).cgColor
greenViewController.view.layer?.backgroundColor = NSColor.green.withAlphaComponent(0.2).cgColor
yellowViewController.view.layer?.backgroundColor = NSColor.yellow.withAlphaComponent(0.2).cgColor

familyViewController.addChild(blueViewController, height: 200)
familyViewController.addChild(redViewController, height: 200)
familyViewController.addChild(greenViewController, height: 200)
familyViewController.addChild(yellowViewController, height: 200)

PlaygroundPage.current.liveView = familyViewController.view
PlaygroundPage.current.needsIndefiniteExecution = true
