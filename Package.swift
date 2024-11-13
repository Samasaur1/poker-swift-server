// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "poker-swift-server",
    platforms: [.macOS(.v12)],
    dependencies: [
        .package(url: "https://github.com/Samasaur1/poker-swift-core", from: "1.0.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "poker-swift-server",
            dependencies: [.product(name: "Poker", package: "poker-swift-core")]
        ),
    ]
)
