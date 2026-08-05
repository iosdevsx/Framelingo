// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "ShortsFeature",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "ShortsFeature", targets: ["ShortsFeature"]),
        .library(name: "ShortsFeatureImpl", targets: ["ShortsFeatureImpl"]),
    ],
    dependencies: [
        .package(path: "../Application"),
        .package(path: "../DesignSystem"),
        .package(path: "../Project"),
        .package(path: "../Shorts"),
        .package(path: "../Subtitles"),
        .package(path: "../VideoRendering"),
    ],
    targets: [
        .target(
            name: "ShortsFeature",
            dependencies: [],
            path: "Sources/Api"
        ),
        .target(
            name: "ShortsFeatureImpl",
            dependencies: [
                "ShortsFeature",
                .product(name: "Application", package: "Application"),
                .product(name: "DesignSystem", package: "DesignSystem"),
                .product(name: "Project", package: "Project"),
                .product(name: "Shorts", package: "Shorts"),
                .product(name: "Subtitles", package: "Subtitles"),
                .product(name: "VideoRendering", package: "VideoRendering"),
            ],
            path: "Sources/Impl"
        ),
    ],
    swiftLanguageModes: [.v5]
)
