// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "IOSApp",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "IOSApp", targets: ["IOSApp"]),
    ],
    dependencies: [
        .package(path: "../../Core/Project"),
        .package(path: "../../Core/Subtitles"),
        .package(path: "../../Infrastructure/SpeechToText"),
        .package(path: "../../Infrastructure/VideoExport"),
        .package(path: "../../Features/HomeFeature"),
        .package(path: "../../Features/PlayerFeature"),
        .package(path: "../../Features/SubtitleEditorFeature"),
        .package(path: "../../Workflows/ProjectSession"),
        .package(path: "../../Workflows/ProjectPreparation"),
        .package(path: "../../Workflows/TranscriptionPipeline"),
        .package(path: "../../Workflows/TranslationPipeline"),
    ],
    targets: [
        .target(
            name: "IOSApp",
            dependencies: [
                .product(name: "Project", package: "Project"),
                .product(name: "ProjectImpl", package: "Project"),
                .product(name: "HomeFeature", package: "HomeFeature"),
                .product(name: "PlayerFeature", package: "PlayerFeature"),
                .product(name: "SubtitleEditorFeature", package: "SubtitleEditorFeature"),
                .product(name: "ProjectSession", package: "ProjectSession"),
                .product(name: "ProjectSessionImpl", package: "ProjectSession"),
                .product(name: "ProjectPreparation", package: "ProjectPreparation"),
                .product(name: "SpeechToText", package: "SpeechToText"),
                .product(name: "Subtitles", package: "Subtitles"),
                .product(name: "TranscriptionPipeline", package: "TranscriptionPipeline"),
                .product(name: "TranslationPipeline", package: "TranslationPipeline"),
                .product(name: "VideoExport", package: "VideoExport"),
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "IOSAppTests",
            dependencies: [
                "IOSApp",
                .product(name: "Project", package: "Project"),
                .product(name: "ProjectImpl", package: "Project"),
                .product(name: "Subtitles", package: "Subtitles"),
            ],
            path: "Tests/IOSAppTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
