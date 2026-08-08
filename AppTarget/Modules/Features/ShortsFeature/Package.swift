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
        .package(path: "../../UI/DesignSystem"),
        .package(path: "../../Core/Shorts"),
        .package(path: "../../Core/Subtitles"),
        .package(path: "../../Infrastructure/VideoRendering"),
    ],
    targets: [
        .target(
            name: "ShortsFeature",
            dependencies: [
                .product(name: "Shorts", package: "Shorts"),
                .product(name: "Subtitles", package: "Subtitles"),
                .product(name: "VideoRendering", package: "VideoRendering"),
            ],
            path: "Sources/Api"
        ),
        .target(
            name: "ShortsFeatureImpl",
            dependencies: [
                "ShortsFeature",
                .product(name: "DesignSystem", package: "DesignSystem"),
                .product(name: "Shorts", package: "Shorts"),
                .product(name: "Subtitles", package: "Subtitles"),
                .product(name: "VideoRendering", package: "VideoRendering"),
            ],
            path: "Sources/Impl"
        ),
        .testTarget(
            name: "ShortsFeatureTests",
            dependencies: [
                "ShortsFeature",
                "ShortsFeatureImpl",
                .product(name: "Shorts", package: "Shorts"),
            ],
            path: "Tests/ShortsFeatureTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
