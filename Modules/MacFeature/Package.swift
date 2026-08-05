// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "MacFeature",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "MacFeature", targets: ["MacFeature"]),
        .library(name: "MacFeatureImpl", targets: ["MacFeatureImpl"]),
    ],
    dependencies: [
        .package(path: "../AppUpdate"),
        .package(path: "../Application"),
        .package(path: "../DesignSystem"),
        .package(path: "../ExportFeature"),
        .package(path: "../HomeFeature"),
        .package(path: "../Media"),
        .package(path: "../Project"),
        .package(path: "../ProjectFeature"),
        .package(path: "../Settings"),
        .package(path: "../SettingsFeature"),
        .package(path: "../SpeakerAnalysis"),
        .package(path: "../SpeechToText"),
        .package(path: "../Subtitles"),
        .package(path: "../Timeline"),
        .package(path: "../Translation"),
        .package(path: "../VideoRendering"),
    ],
    targets: [
        .target(
            name: "MacFeature",
            dependencies: [
                .product(name: "Application", package: "Application"),
                .product(name: "Project", package: "Project"),
                .product(name: "SpeechToText", package: "SpeechToText"),
                .product(name: "Subtitles", package: "Subtitles"),
            ],
            path: "Sources/Api"
        ),
        .target(
            name: "MacFeatureImpl",
            dependencies: [
                "MacFeature",
                .product(name: "AppUpdate", package: "AppUpdate"),
                .product(name: "AppUpdateImpl", package: "AppUpdate"),
                .product(name: "Application", package: "Application"),
                .product(name: "ApplicationImpl", package: "Application"),
                .product(name: "DesignSystem", package: "DesignSystem"),
                .product(name: "ExportFeatureImpl", package: "ExportFeature"),
                .product(name: "HomeFeatureImpl", package: "HomeFeature"),
                .product(name: "MediaImpl", package: "Media"),
                .product(name: "Project", package: "Project"),
                .product(name: "ProjectImpl", package: "Project"),
                .product(name: "ProjectFeature", package: "ProjectFeature"),
                .product(name: "ProjectFeatureImpl", package: "ProjectFeature"),
                .product(name: "SettingsImpl", package: "Settings"),
                .product(name: "SettingsFeatureImpl", package: "SettingsFeature"),
                .product(name: "SpeakerAnalysis", package: "SpeakerAnalysis"),
                .product(name: "SpeakerAnalysisImpl", package: "SpeakerAnalysis"),
                .product(name: "SpeechToTextImpl", package: "SpeechToText"),
                .product(name: "Subtitles", package: "Subtitles"),
                .product(name: "SubtitlesImpl", package: "Subtitles"),
                .product(name: "TimelineImpl", package: "Timeline"),
                .product(name: "TranslationImpl", package: "Translation"),
                .product(name: "VideoRendering", package: "VideoRendering"),
                .product(name: "VideoRenderingImpl", package: "VideoRendering"),
            ],
            path: "Sources/Impl"
        ),
    ],
    swiftLanguageModes: [.v5]
)
