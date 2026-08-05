// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "ProjectFeature",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "ProjectFeature", targets: ["ProjectFeature"]),
        .library(name: "ProjectFeatureImpl", targets: ["ProjectFeatureImpl"]),
    ],
    dependencies: [
        .package(path: "../Application"),
        .package(path: "../DesignSystem"),
        .package(path: "../ExportFeature"),
        .package(path: "../PlayerFeature"),
        .package(path: "../Project"),
        .package(path: "../ShortsFeature"),
        .package(path: "../SubtitleEditorFeature"),
        .package(path: "../Subtitles"),
        .package(path: "../Timeline"),
        .package(path: "../TimelineFeature"),
        .package(path: "../VideoRendering"),
    ],
    targets: [
        .target(
            name: "ProjectFeature",
            dependencies: [],
            path: "Sources/Api"
        ),
        .target(
            name: "ProjectFeatureImpl",
            dependencies: [
                "ProjectFeature",
                .product(name: "Application", package: "Application"),
                .product(name: "DesignSystem", package: "DesignSystem"),
                .product(name: "ExportFeatureImpl", package: "ExportFeature"),
                .product(name: "PlayerFeature", package: "PlayerFeature"),
                .product(name: "PlayerFeatureImpl", package: "PlayerFeature"),
                .product(name: "Project", package: "Project"),
                .product(name: "ShortsFeatureImpl", package: "ShortsFeature"),
                .product(name: "SubtitleEditorFeature", package: "SubtitleEditorFeature"),
                .product(name: "SubtitleEditorFeatureImpl", package: "SubtitleEditorFeature"),
                .product(name: "Subtitles", package: "Subtitles"),
                .product(name: "Timeline", package: "Timeline"),
                .product(name: "TimelineFeature", package: "TimelineFeature"),
                .product(name: "TimelineFeatureImpl", package: "TimelineFeature"),
                .product(name: "VideoRendering", package: "VideoRendering"),
            ],
            path: "Sources/Impl"
        ),
    ],
    swiftLanguageModes: [.v5]
)
