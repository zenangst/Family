import Cocoa

public class FamilyContentView: NSView {
  private struct Observer: Equatable {
    let view: NSView
    let keyValueObservation: NSKeyValueObservation

    static func == (lhs: Observer, rhs: Observer) -> Bool {
      return lhs.view === rhs.view && lhs.keyValueObservation === rhs.keyValueObservation
    }
  }
  private var observers = [Observer]()
  public override var isFlipped: Bool { return true }

  weak var familyScrollView: FamilyScrollView?

  deinit {
    observers.removeAll()
  }

  override public func didAddSubview(_ subview: NSView) {
    super.didAddSubview(subview)

    let frameObserver = subview.observe(\.frame, options: [.new, .old], changeHandler: { [weak self] (_, value) in
      guard let newValue = value.newValue, let oldValue = value.oldValue else {
        return
      }

      if newValue.size != oldValue.size {
        self?.familyScrollView?.layoutViews()
      }
    })
    observers.append(Observer(view: subview, keyValueObservation: frameObserver))


    let hiddenObserver = subview.observe(\.isHidden, options: [.new, .old], changeHandler: { [weak self] (_, value) in
      guard let newValue = value.newValue, let oldValue = value.oldValue else {
        return
      }

      if newValue != oldValue {
        self?.familyScrollView?.layoutViews()
      }
    })
    observers.append(Observer(view: subview, keyValueObservation: hiddenObserver))
    familyScrollView?.didAddScrollViewToContainer(subview)
  }

  override public func willRemoveSubview(_ subview: NSView) {
    for observer in observers.filter({ $0.view === subview }) {
      if let index = observers.index(where: { $0 == observer }) {
        observers.remove(at: index)
      }
    }
    familyScrollView?.willRemoveSubview(subview)
  }
}
