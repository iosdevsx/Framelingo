// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "ExportFeature",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "ExportFeature", targets: ["ExportFeature"]),
        .library(name: "ExportFeatureImpl", targets: ["ExportFeatureImpl"]),
    ],
    dependencies: [
        .package(path: "../DesignSystem"),
        .package(path: "../Media"),
        .package(path: "../Project"),
        .package(path: "../Subtitles"),
        .package(path: "../VideoRendering"),
    ],
    targets: [
        .target(
            name: "ExportFeature",
            dependencies: [
                .product(name: "Project", package: "Project"),
                .product(name: "Subtitles", package: "Subtitles"),
                .product(name: "VideoRendering", package: "VideoRendering"),
            ],
            path: "Sources/Api"
        ),
        .target(
            name: "ExportFeatureImpl",
            dependencies: [
                "ExportFeature",
                .product(name: "DesignSystem", package: "DesignSystem"),
                .product(name: "Media", package: "Media"),
                .product(name: "Project", package: "Project"),
                .product(name: "Subtitles", package: "Subtitles"),
                .product(name: "VideoRendering", package: "VideoRendering"),
            ],
            path: "Sources/Impl"
        ),
        .testTarget(
            name: "ExportFeatureTests",
            dependencies: [
                "ExportFeature",
                .product(name: "Subtitles", package: "Subtitles"),
            ],
            path: "Tests/ExportFeatureTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
