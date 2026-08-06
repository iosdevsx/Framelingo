// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SettingsFeature",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "SettingsFeature", targets: ["SettingsFeature"]),
        .library(name: "SettingsFeatureImpl", targets: ["SettingsFeatureImpl"]),
    ],
    dependencies: [
        .package(path: "../DesignSystem"),
        .package(path: "../Project"),
        .package(path: "../Settings"),
        .package(path: "../SpeechToText"),
        .package(path: "../Subtitles"),
        .package(path: "../VideoRendering"),
    ],
    targets: [
        .target(
            name: "SettingsFeature",
            dependencies: [],
            path: "Sources/Api"
        ),
        .target(
            name: "SettingsFeatureImpl",
            dependencies: [
                "SettingsFeature",
                .product(name: "DesignSystem", package: "DesignSystem"),
                .product(name: "Project", package: "Project"),
                .product(name: "Settings", package: "Settings"),
                .product(name: "SpeechToText", package: "SpeechToText"),
                .product(name: "Subtitles", package: "Subtitles"),
                .product(name: "VideoRendering", package: "VideoRendering"),
            ],
            path: "Sources/Impl"
        ),
        .testTarget(
            name: "SettingsFeatureImplTests",
            dependencies: [
                "SettingsFeatureImpl",
                .product(name: "Project", package: "Project"),
                .product(name: "Settings", package: "Settings"),
                .product(name: "SpeechToText", package: "SpeechToText"),
                .product(name: "VideoRendering", package: "VideoRendering"),
            ],
            path: "Tests/SettingsFeatureImplTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
