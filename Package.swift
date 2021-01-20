// swift-tools-version:5.3

import PackageDescription

let package = Package(
  name: "Family",
  platforms: [.iOS(.v10), .tvOS(.v10), .macOS(.v10_12)],
  products: [
    .library(
      name: "Family",
      targets: ["Family"]
    )
  ],
  dependencies: [],
  targets: [
    .target(
      name: "Family",
      path: "Sources"
    ),
    .testTarget(
      name: "macOS-Tests",
      dependencies: ["Family"],
      path: "Tests",
      exclude: [
        "iOS", "tvOS", "Shared", "UIKit"
      ]),
    .testTarget(
      name: "UIKit-Tests",
      dependencies: ["Family"],
      path: "Tests",
      exclude: [
        "AppKit", "tvOS", "iOS"
      ],
      sources: [
        "Shared",
        "UIKit"
      ]),
    .testTarget(
      name: "iOS-Tests",
      dependencies: ["Family"],
      path: "Tests",
      exclude: [
        "AppKit", "tvOS", "Shared", "UIKit"
      ]),
    .testTarget(
      name: "tvOS-Tests",
      dependencies: ["Family"],
      path: "Tests",
      exclude: [
        "AppKit", "iOS", "Shared", "UIKit"
      ])
  ]
)

