// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TranscriptionPipeline",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "TranscriptionPipeline", targets: ["TranscriptionPipeline"]),
        .library(name: "TranscriptionPipelineImpl", targets: ["TranscriptionPipelineImpl"]),
    ],
    dependencies: [
        .package(path: "../Project"),
        .package(path: "../SpeakerAnalysis"),
        .package(path: "../SpeechToText"),
        .package(path: "../Subtitles"),
        .package(path: "../VideoRendering"),
    ],
    targets: [
        .target(
            name: "TranscriptionPipeline",
            dependencies: [
                .product(name: "Project", package: "Project"),
                .product(name: "SpeechToText", package: "SpeechToText"),
            ],
            path: "Sources/Api"
        ),
        .target(
            name: "TranscriptionPipelineImpl",
            dependencies: [
                "TranscriptionPipeline",
                .product(name: "Project", package: "Project"),
                .product(name: "SpeakerAnalysis", package: "SpeakerAnalysis"),
                .product(name: "SpeechToText", package: "SpeechToText"),
                .product(name: "Subtitles", package: "Subtitles"),
                .product(name: "VideoRendering", package: "VideoRendering"),
            ],
            path: "Sources/Impl"
        ),
        .testTarget(
            name: "TranscriptionPipelineAPITests",
            dependencies: ["TranscriptionPipeline"],
            path: "Tests/TranscriptionPipelineAPITests"
        ),
        .testTarget(
            name: "TranscriptionPipelineImplTests",
            dependencies: [
                "TranscriptionPipeline",
                "TranscriptionPipelineImpl",
                .product(name: "Project", package: "Project"),
                .product(name: "SpeakerAnalysis", package: "SpeakerAnalysis"),
                .product(name: "SpeechToText", package: "SpeechToText"),
                .product(name: "Subtitles", package: "Subtitles"),
                .product(name: "VideoRendering", package: "VideoRendering"),
            ],
            path: "Tests/TranscriptionPipelineImplTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
