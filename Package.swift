// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "Family",
    platforms: [.iOS(.v9), .tvOS(.v14), .macOS(.v11)],
    products: [
        .library(
            name: "Family-Mobile",
            targets: ["Family-Mobile"]),
        .library(
            name: "Family-macOS",
            targets: ["Family-macOS"])
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
            path: "Sources/Shared")
    ]
)
