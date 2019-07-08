#if os(macOS)
import Cocoa

public enum BackgroundKind {
  case color(NSColor)
  case view(View)
}
#else
import UIKit

public enum BackgroundKind {
  case color(UIColor)
  case view(View)
}
#endif
