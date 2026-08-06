// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "HomeFeature",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "HomeFeature", targets: ["HomeFeature"]),
        .library(name: "HomeFeatureImpl", targets: ["HomeFeatureImpl"]),
    ],
    dependencies: [
        .package(path: "../Media"),
        .package(path: "../Project"),
        .package(path: "../Subtitles"),
    ],
    targets: [
        .target(
            name: "HomeFeature",
            dependencies: [
                .product(name: "Project", package: "Project"),
            ],
            path: "Sources/Api"
        ),
        .target(
            name: "HomeFeatureImpl",
            dependencies: [
                "HomeFeature",
                .product(name: "Media", package: "Media"),
                .product(name: "Project", package: "Project"),
                .product(name: "Subtitles", package: "Subtitles"),
            ],
            path: "Sources/Impl"
        ),
        .testTarget(
            name: "HomeFeatureImplTests",
            dependencies: [
                "HomeFeatureImpl",
                .product(name: "Media", package: "Media"),
                .product(name: "Project", package: "Project"),
                .product(name: "Subtitles", package: "Subtitles"),
            ],
            path: "Tests/HomeFeatureImplTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
