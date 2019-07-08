![Family logo](https://github.com/zenangst/Family/blob/master/Images/Family-header.png?raw=true)
<div align="center">

[![CI Status](https://travis-ci.org/zenangst/Family.svg?branch=master)](https://travis-ci.org/zenangst/Family)
[![Version](https://img.shields.io/cocoapods/v/Family.svg?style=flat)](http://cocoadocs.org/docsets/Family)
[![Carthage Compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![codecov](https://codecov.io/gh/zenangst/Family/branch/master/graph/badge.svg)](https://codecov.io/gh/zenangst/Family)
[![License](https://img.shields.io/cocoapods/l/Family.svg?style=flat)](http://cocoadocs.org/docsets/Family)
[![Platform](https://img.shields.io/cocoapods/p/Family.svg?style=flat)](http://cocoadocs.org/docsets/Family)
![Swift](https://img.shields.io/badge/%20in-swift%204.2-orange.svg)

</div>

## Description

<img src="https://github.com/zenangst/Family/blob/master/Images/Family-icon.png?raw=true" alt="Family Icon" align="right" />

Family is a child view controller framework that makes setting up your parent controllers as easy as pie.
With a simple yet powerful public API, you can build complex layouts without losing maintainability, leaving you to focus on what matters: making your applications pop and your business logic shine.

This framework was built to make it easier to build and maintain parent controllers, also known as flow controllers. Using child view controllers can make your code more modular, flexible and testable. It addresses one of the biggest shortcomings of the vanilla approach: how do you get a continuous scrolling experience while keeping dequeuing intact?

This is where Family framework comes in. With the help of its layout algorithm, all your regular- and scroll views get stacked in the same linear vertical order you add them to the hierarchy. To achieve a continuous scrolling view, your child scroll views no longer scroll themselves, but get their new content offset passed to them by the parent scroll view, which the framework handles for you. The framework also modifies the views' frames on the fly, constraining the height to the window.

## The story behind Family
If you are interested in the origin story behind Family, then you can read this [Medium article](https://medium.com/hyperoslo/why-i-wrote-family-framework-d1c3cb062c85).

## Features

- [x] 🍩Animation support.
- [x] 🤳🏻Continuous scrolling with multiple scroll views.
- [x] 📏Margins between child view controllers.
- [x] 🌀Table view and collection view dequeuing.
- [x] 🍭Supports custom spacing between views.
- [x] 📱iOS support.
- [x] 💻macOS support.
- [x] 📺tvOS support.

## Usage

The new public API:

```swift
body(withDuration: 0) {
  add(detailViewController)
  .background(.view(backgroundView))
  .padding(.init(top: 20, left: 20, bottom: 20, right: 20))
  .margin(.init(top: 20, left: 0, bottom: 20, right: 0))
}
```

Add a regular child view controller:

```swift
let familyController = FamilyViewController()
let viewController = UIViewController()

familyController.addChild(viewController)
```

Add a child view controller constrained by height:

```swift
let familyController = FamilyViewController()
let viewController = UIViewController()

familyController.addChild(viewController, height: 175)
```

Add a child view controller with a custom view on the controller:

```swift
let familyController = FamilyViewController()
let customController = CustomViewController()

// This will add the scroll view of the custom controller
// instead of the controllers view.
familyController.addChild(customController, view: { $0.scrollView })
```

Move a view controller:

```swift
familyController.moveChild(customController, to: 1)
```

Perform batch updates (it is encouraged to use performBatchUpdates when updaing more than one view controller):

```swift
familyController.performBatchUpdates({ controller in
  controller.addChild(controller1)
  controller.addChild(controller2)
  controller.moveChild(controller2, to: 0)
  controller3.removeFromParent()
})
```

Adding animations

When adding animations, not that you have to give them a key.
```swift
let basicAnimation = CABasicAnimation()
basicAnimation.duration = 0.5
controller.view.layer.add(springAnimation, forKey: "Basic Animations")

let springAnimation = CASpringAnimation()
springAnimation.damping = 0.6
springAnimation.initialVelocity = 0.6
springAnimation.mass = 0.4
springAnimation.duration = 0.6
springAnimation.isRemovedOnCompletion = false
controller.view.layer.add(springAnimation, forKey: "Spring Animations")
```


## Installation

**Family** is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'Family'
```

and then run
```sh
pod install
```

**Family** is also available through [Carthage](https://github.com/Carthage/Carthage).
To install just write into your Cartfile:

```ruby
github "zenangst/Family"
```

and then run
```sh
carthage install
```

When it's finished, install the built framework (which can be found in the `Carthage/Build` folder) into your Xcode project.

**Family** can also be installed manually. Just download and drop `Sources` folders in your project.

## Author

Christoffer Winterkvist, christoffer@winterkvist.com

## Contributing

We would love you to contribute to **Family**, check the [CONTRIBUTING](https://github.com/zenangst/Family/blob/master/CONTRIBUTING.md) file for more info.

## Credits

- [hyperoslo's Spots](https://github.com/hyperoslo/Spots) uses the same kind of implementation in order to render its component.
- [Ole Begemanns](https://github.com/ole/) implementation of [OLEContainerScrollView](https://github.com/ole/OLEContainerScrollView) is the basis for `SpotsScrollView`, we salute you.
Reference: http://oleb.net/blog/2014/05/scrollviews-inside-scrollviews/

## License

**Family** is available under the MIT license. See the [LICENSE](https://github.com/zenangst/Family/blob/master/LICENSE.md) file for more info.
