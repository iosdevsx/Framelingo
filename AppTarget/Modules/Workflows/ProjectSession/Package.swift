// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "ProjectSession",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(name: "ProjectSession", targets: ["ProjectSession"]),
        .library(name: "ProjectSessionImpl", targets: ["ProjectSessionImpl"]),
    ],
    dependencies: [
        .package(path: "../../Core/Project"),
        .package(path: "../ProjectPreparation"),
        .package(path: "../../Core/Shorts"),
        .package(path: "../../Infrastructure/SpeechToText"),
        .package(path: "../../Core/SpeakerAnalysis"),
        .package(path: "../../Core/Subtitles"),
        .package(path: "../../Core/Timeline"),
        .package(path: "../TranscriptionPipeline"),
        .package(path: "../TranslationPipeline"),
        .package(path: "../../Infrastructure/VideoExport"),
        .package(path: "../../Infrastructure/VideoRendering"),
    ],
    targets: [
        .target(
            name: "ProjectSession",
            dependencies: [
                .product(name: "Project", package: "Project"),
                .product(name: "ProjectPreparation", package: "ProjectPreparation"),
                .product(name: "Shorts", package: "Shorts"),
                .product(name: "Subtitles", package: "Subtitles"),
                .product(name: "Timeline", package: "Timeline"),
                .product(name: "TranscriptionPipeline", package: "TranscriptionPipeline"),
                .product(name: "TranslationPipeline", package: "TranslationPipeline"),
                .product(name: "VideoExport", package: "VideoExport"),
                .product(name: "VideoRendering", package: "VideoRendering"),
            ],
            path: "Sources/Api"
        ),
        .target(
            name: "ProjectSessionImpl",
            dependencies: [
                "ProjectSession",
                .product(name: "Project", package: "Project"),
                .product(name: "ProjectPreparation", package: "ProjectPreparation"),
                .product(name: "Shorts", package: "Shorts"),
                .product(name: "Subtitles", package: "Subtitles"),
                .product(name: "Timeline", package: "Timeline"),
                .product(name: "TranscriptionPipeline", package: "TranscriptionPipeline"),
                .product(name: "TranslationPipeline", package: "TranslationPipeline"),
                .product(name: "VideoExport", package: "VideoExport"),
                .product(name: "VideoRendering", package: "VideoRendering"),
            ],
            path: "Sources/Impl"
        ),
        .testTarget(
            name: "ProjectSessionAPITests",
            dependencies: ["ProjectSession"],
            path: "Tests/ApiTests"
        ),
        .testTarget(
            name: "ProjectSessionImplTests",
            dependencies: [
                "ProjectSession",
                "ProjectSessionImpl",
                .product(name: "SpeakerAnalysis", package: "SpeakerAnalysis"),
                .product(name: "SpeechToText", package: "SpeechToText"),
                .product(name: "TimelineImpl", package: "Timeline"),
            ],
            path: "Tests/ImplTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
