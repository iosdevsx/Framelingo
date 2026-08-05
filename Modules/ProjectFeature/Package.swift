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
        .package(path: "../Media"),
        .package(path: "../PlayerFeature"),
        .package(path: "../Project"),
        .package(path: "../Settings"),
        .package(path: "../Shorts"),
        .package(path: "../ShortsFeature"),
        .package(path: "../SpeakerAnalysis"),
        .package(path: "../SpeechToText"),
        .package(path: "../SubtitleEditorFeature"),
        .package(path: "../Subtitles"),
        .package(path: "../Timeline"),
        .package(path: "../TimelineFeature"),
        .package(path: "../Translation"),
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
                .product(name: "ExportFeature", package: "ExportFeature"),
                .product(name: "ExportFeatureImpl", package: "ExportFeature"),
                .product(name: "PlayerFeature", package: "PlayerFeature"),
                .product(name: "PlayerFeatureImpl", package: "PlayerFeature"),
                .product(name: "Project", package: "Project"),
                .product(name: "Settings", package: "Settings"),
                .product(name: "Shorts", package: "Shorts"),
                .product(name: "ShortsFeature", package: "ShortsFeature"),
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
        .testTarget(
            name: "ProjectFeatureImplTests",
            dependencies: [
                "ProjectFeature",
                "ProjectFeatureImpl",
                .product(name: "Application", package: "Application"),
                .product(name: "ApplicationImpl", package: "Application"),
                .product(name: "Media", package: "Media"),
                .product(name: "Project", package: "Project"),
                .product(name: "Settings", package: "Settings"),
                .product(name: "Shorts", package: "Shorts"),
                .product(name: "SpeakerAnalysis", package: "SpeakerAnalysis"),
                .product(name: "SpeechToText", package: "SpeechToText"),
                .product(name: "Subtitles", package: "Subtitles"),
                .product(name: "Timeline", package: "Timeline"),
                .product(name: "Translation", package: "Translation"),
                .product(name: "VideoRendering", package: "VideoRendering"),
            ],
            path: "Tests/ProjectFeatureImplTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
