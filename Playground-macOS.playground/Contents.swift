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
let redViewController = CodeViewController.init(nibName: nil, bundle: nil)
redViewController.view.layer?.backgroundColor = NSColor.red.withAlphaComponent(0.2).cgColor
redViewController.view.setFrameSize(frame.size)

//let familyController = FamilyViewController.init(nibName: nil, bundle: nil)
//familyController.view.setFrameSize(frame.size)
//familyController.addChildViewController(redViewController)


PlaygroundPage.current.liveView = redViewController.view
PlaygroundPage.current.needsIndefiniteExecution = true
