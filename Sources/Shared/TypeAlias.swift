#if os(macOS)
  import Cocoa
  public typealias ViewController = NSViewController
  public typealias ScrollView = NSScrollView
  public typealias View = NSView
  public typealias Insets = NSEdgeInsets
#else
  import UIKit
  public typealias ViewController = UIViewController
  public typealias ScrollView = UIScrollView
  public typealias View = UIView
  public typealias Insets = UIEdgeInsets
#endif
