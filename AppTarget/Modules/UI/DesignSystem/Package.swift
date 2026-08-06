// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "DesignSystem",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "DesignSystemImpl", targets: ["DesignSystemImpl"]),
    ],
    targets: [
        .target(name: "DesignSystem", path: "Sources/Api"),
        .target(
            name: "DesignSystemImpl",
            dependencies: ["DesignSystem"],
            path: "Sources/Impl"
        ),
        .testTarget(
            name: "DesignSystemImplTests",
            dependencies: ["DesignSystem", "DesignSystemImpl"],
            path: "Tests/DesignSystemImplTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
