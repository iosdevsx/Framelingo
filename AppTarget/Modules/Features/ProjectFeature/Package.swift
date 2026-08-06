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
        .package(path: "../../UI/DesignSystem"),
        .package(path: "../ExportFeature"),
        .package(path: "../PlayerFeature"),
        .package(path: "../../Core/Project"),
        .package(path: "../../Workflows/ProjectPreparation"),
        .package(path: "../../Workflows/ProjectSession"),
        .package(path: "../../Core/Shorts"),
        .package(path: "../ShortsFeature"),
        .package(path: "../SubtitleEditorFeature"),
        .package(path: "../../Core/Subtitles"),
        .package(path: "../../Core/Timeline"),
        .package(path: "../TimelineFeature"),
        .package(path: "../../Infrastructure/VideoExport"),
        .package(path: "../../Infrastructure/VideoRendering"),
    ],
    targets: [
        .target(
            name: "ProjectFeature",
            dependencies: [
                .product(name: "ExportFeature", package: "ExportFeature"),
                .product(name: "PlayerFeature", package: "PlayerFeature"),
                .product(name: "ShortsFeature", package: "ShortsFeature"),
                .product(name: "SubtitleEditorFeature", package: "SubtitleEditorFeature"),
                .product(name: "TimelineFeature", package: "TimelineFeature"),
            ],
            path: "Sources/Api"
        ),
        .target(
            name: "ProjectFeatureImpl",
            dependencies: [
                "ProjectFeature",
                .product(name: "DesignSystem", package: "DesignSystem"),
                .product(name: "ExportFeature", package: "ExportFeature"),
                .product(name: "PlayerFeature", package: "PlayerFeature"),
                .product(name: "Project", package: "Project"),
                .product(name: "ProjectPreparation", package: "ProjectPreparation"),
                .product(name: "ProjectSession", package: "ProjectSession"),
                .product(name: "VideoExport", package: "VideoExport"),
                .product(name: "Shorts", package: "Shorts"),
                .product(name: "ShortsFeature", package: "ShortsFeature"),
                .product(name: "SubtitleEditorFeature", package: "SubtitleEditorFeature"),
                .product(name: "Subtitles", package: "Subtitles"),
                .product(name: "Timeline", package: "Timeline"),
                .product(name: "TimelineFeature", package: "TimelineFeature"),
                .product(name: "VideoRendering", package: "VideoRendering"),
            ],
            path: "Sources/Impl"
        ),
        .testTarget(
            name: "ProjectFeatureImplTests",
            dependencies: [
                "ProjectFeature",
                "ProjectFeatureImpl",
                .product(name: "ExportFeature", package: "ExportFeature"),
                .product(name: "PlayerFeature", package: "PlayerFeature"),
                .product(name: "Project", package: "Project"),
                .product(name: "ProjectSession", package: "ProjectSession"),
                .product(name: "ProjectSessionImpl", package: "ProjectSession"),
                .product(name: "Shorts", package: "Shorts"),
                .product(name: "ShortsFeature", package: "ShortsFeature"),
                .product(name: "Subtitles", package: "Subtitles"),
                .product(name: "SubtitleEditorFeature", package: "SubtitleEditorFeature"),
                .product(name: "Timeline", package: "Timeline"),
                .product(name: "TimelineImpl", package: "Timeline"),
                .product(name: "TimelineFeature", package: "TimelineFeature"),
                .product(name: "VideoRendering", package: "VideoRendering"),
            ],
            path: "Tests/ProjectFeatureImplTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
