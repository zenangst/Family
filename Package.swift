// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "Family",
    platforms: [.iOS(.v10), .tvOS(.v14), .macOS(.v10_11)],
    products: [
        .library(
            name: "Family-Mobile",
            targets: ["Family-Mobile"]),
        .library(
            name: "Family-macOS",
            targets: ["Family-macOS"]),
        .library(
            name: "Family-Shared",
            targets: ["Family-Shared"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Family-Mobile",
            dependencies: ["Family-Shared"],
            path: "Sources/iOS+tvOS"),
        .target(
            name: "Family-macOS",
            dependencies: ["Family-Shared"],
            path: "Sources/macOS"),
        .target(
            name: "Family-Shared",
            dependencies: [],
            path: "Sources/Shared"),
        .testTarget(name: "iOS-Tests",
                    dependencies: ["Family-Mobile", "Family-Shared"],
                    path: "Tests/iOS"),
        .testTarget(name: "iOS+tvOS-Tests",
                    dependencies: ["Family-Mobile", "Family-Shared"],
                    path: "Tests/iOS+tvOS"),
        .testTarget(name: "macOS-Tests",
                    dependencies: ["Family-macOS", "Family-Shared"],
                    path: "Tests/macOS")
    ]
)
