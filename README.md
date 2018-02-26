![Family logo](https://github.com/zenangst/Family/blob/master/Images/Family-header.png?raw=true)
<div align="center">

[![CI Status](https://travis-ci.org/zenangst/Family.svg?branch=master)](https://travis-ci.org/zenangst/Family)
[![Version](https://img.shields.io/cocoapods/v/Family.svg?style=flat)](http://cocoadocs.org/docsets/Family)
[![Carthage Compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![License](https://img.shields.io/cocoapods/l/Family.svg?style=flat)](http://cocoadocs.org/docsets/Family)
[![Platform](https://img.shields.io/cocoapods/p/Family.svg?style=flat)](http://cocoadocs.org/docsets/Family)
![Swift](https://img.shields.io/badge/%20in-swift%204.0-orange.svg)

</div>

## Description

<img src="https://github.com/zenangst/Family/blob/master/Images/Family-icon.png?raw=true" alt="Family Icon" align="right" />

Family is a child view controller framework that makes setting up your parent controllers as easy as pie.
With a simple yet powerful public API, you can build complex layout without losing maintainability. Leaving you to focus on what matters, making your applications pop and your business logic shine.

This framework was built to make it easier to build and maintain parent controllers, or made famous by other in the industry as flow controllers. Using child view controllers can make your code more modular, flexible and testable. There are just some shortcoming with the vanilla approach when dealing with child view controllers.

How do you get a continuous scrolling experience while keeping dequeuing intact?

This is where Family framework comes in, with the help of its layout algorithm, all your regular- and scroll views get stacked in the same linear vertical order you add them to the hierarchy. To achieve a continuous, your scroll-views no longer scroll themselves but get their new content offset passed to them by the parent scroll view that is handled for you internally in the framework.
The algorithm also modifies the views frames on the fly, constraining the height to the window.

## The story behind Family
If you are interested in the origin story behind Family, then you can read this [Medium article](https://medium.com/hyperoslo/why-i-wrote-family-framework-d1c3cb062c85).

## Features

- [x] 🍩Animation support.
- [x] 🤳🏻Continuous scrolling with multiple scroll views.
- [x] 📏Margins between child view controllers.
- [x] 🌀Table view and collection view dequeuing.
- [x] 📱iOS support.
- [x] 💻macOS support.
- [x] 📺tvOS support.

## Usage

Adding a regular child view controller.

```swift
let familyController = FamilyViewController()
let viewController = UIViewController()

familyController.addChildViewController(viewController)
```

Adding a child view controller constrained in height.

```swift
let familyController = FamilyViewController()
let viewController = UIViewController()

familyController.addChildViewController(viewController, height: 175)
```

Adding a child view controller with a custom view on the controller.

```swift
let familyController = FamilyViewController()
let customController = CustomViewController()

// This will add the scroll view of the custom controller
// instead of the controllers view.
familyController.addChildViewController(customController, view: { $0.scrollView })
```

## Installation

**Family** is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'Family'
```

**Family** is also available through [Carthage](https://github.com/Carthage/Carthage).
To install just write into your Cartfile:

```ruby
github "zenangst/Family"
```

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
