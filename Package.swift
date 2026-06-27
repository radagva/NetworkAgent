// swift-tools-version:6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NetworkAgent",
    platforms: [.iOS(.v16), .macOS(.v12)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "NetworkAgent",
            targets: ["NetworkAgent"]),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "NetworkAgent",
            dependencies: []),
        .testTarget(
            name: "NetworkAgentTests",
            dependencies: ["NetworkAgent"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
