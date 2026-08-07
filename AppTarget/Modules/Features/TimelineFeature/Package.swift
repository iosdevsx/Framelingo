// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TimelineFeature",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "TimelineFeature", targets: ["TimelineFeature"]),
        .library(name: "TimelineFeatureImpl", targets: ["TimelineFeatureImpl"]),
    ],
    dependencies: [
        .package(path: "../../UI/DesignSystem"),
        .package(path: "../../Core/Shorts"),
        .package(path: "../../Core/SpeakerAnalysis"),
        .package(path: "../../Core/Subtitles"),
        .package(path: "../../Core/Timeline"),
    ],
    targets: [
        .target(
            name: "TimelineFeature",
            dependencies: [
                .product(name: "Shorts", package: "Shorts"),
                .product(name: "SpeakerAnalysis", package: "SpeakerAnalysis"),
                .product(name: "Subtitles", package: "Subtitles"),
                .product(name: "Timeline", package: "Timeline"),
            ],
            path: "Sources/Api"
        ),
        .target(
            name: "TimelineFeatureImpl",
            dependencies: [
                "TimelineFeature",
                .product(name: "DesignSystem", package: "DesignSystem"),
                .product(name: "Shorts", package: "Shorts"),
                .product(name: "SpeakerAnalysis", package: "SpeakerAnalysis"),
                .product(name: "Subtitles", package: "Subtitles"),
                .product(name: "Timeline", package: "Timeline"),
            ],
            path: "Sources/Impl"
        ),
        .testTarget(
            name: "TimelineFeatureImplTests",
            dependencies: ["TimelineFeature", "TimelineFeatureImpl"],
            path: "Tests/TimelineFeatureImplTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
