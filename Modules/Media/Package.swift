// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Media",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(name: "Media", targets: ["Media"]),
        .library(name: "MediaImpl", targets: ["MediaImpl"]),
    ],
    targets: [
        .target(name: "Media", path: "Sources/Api"),
        .target(
            name: "MediaImpl",
            dependencies: ["Media"],
            path: "Sources/Impl"
        ),
        .testTarget(
            name: "MediaImplTests",
            dependencies: ["Media", "MediaImpl"],
            path: "Tests/MediaImplTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
