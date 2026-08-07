// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "AppUpdate",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "AppUpdate", targets: ["AppUpdate"]),
        .library(name: "AppUpdateImpl", targets: ["AppUpdateImpl"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.4"),
    ],
    targets: [
        .target(name: "AppUpdate", path: "Sources/Api"),
        .target(
            name: "AppUpdateImpl",
            dependencies: [
                "AppUpdate",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/Impl"
        ),
        .testTarget(
            name: "AppUpdateImplTests",
            dependencies: ["AppUpdate", "AppUpdateImpl"],
            path: "Tests/AppUpdateImplTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
