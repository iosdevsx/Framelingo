// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SubtitleEditorFeature",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "SubtitleEditorFeature", targets: ["SubtitleEditorFeature"]),
        .library(name: "SubtitleEditorFeatureImpl", targets: ["SubtitleEditorFeatureImpl"]),
    ],
    dependencies: [
        .package(path: "../DesignSystem"),
        .package(path: "../SpeakerAnalysis"),
        .package(path: "../Subtitles"),
    ],
    targets: [
        .target(
            name: "SubtitleEditorFeature",
            dependencies: [
                .product(name: "SpeakerAnalysis", package: "SpeakerAnalysis"),
                .product(name: "Subtitles", package: "Subtitles"),
            ],
            path: "Sources/Api"
        ),
        .target(
            name: "SubtitleEditorFeatureImpl",
            dependencies: [
                "SubtitleEditorFeature",
                .product(name: "DesignSystem", package: "DesignSystem"),
                .product(name: "SpeakerAnalysis", package: "SpeakerAnalysis"),
                .product(name: "Subtitles", package: "Subtitles"),
            ],
            path: "Sources/Impl"
        ),
        .testTarget(
            name: "SubtitleEditorFeatureImplTests",
            dependencies: [
                "SubtitleEditorFeature",
                "SubtitleEditorFeatureImpl",
                .product(name: "Subtitles", package: "Subtitles"),
            ],
            path: "Tests/SubtitleEditorFeatureImplTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
