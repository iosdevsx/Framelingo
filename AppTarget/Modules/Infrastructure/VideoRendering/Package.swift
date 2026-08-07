// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "VideoRendering",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(name: "VideoRendering", targets: ["VideoRendering"]),
        .library(name: "VideoRenderingImpl", targets: ["VideoRenderingImpl"]),
    ],
    dependencies: [
        .package(path: "../FFmpeg"),
        .package(path: "../../Core/Media"),
        .package(path: "../../Core/SpeakerAnalysis"),
        .package(path: "../../Core/Subtitles"),
        .package(path: "../../Core/Timeline"),
    ],
    targets: [
        .target(
            name: "VideoRendering",
            dependencies: [
                .product(name: "SpeakerAnalysis", package: "SpeakerAnalysis"),
                .product(name: "Subtitles", package: "Subtitles"),
            ],
            path: "Sources/Api"
        ),
        .target(
            name: "VideoRenderingImpl",
            dependencies: [
                "VideoRendering",
                .product(name: "FFmpeg", package: "FFmpeg"),
                .product(name: "Media", package: "Media"),
                .product(name: "SpeakerAnalysis", package: "SpeakerAnalysis"),
                .product(name: "Subtitles", package: "Subtitles"),
                .product(name: "Timeline", package: "Timeline"),
            ],
            path: "Sources/Impl"
        ),
        .testTarget(
            name: "VideoRenderingImplTests",
            dependencies: [
                "VideoRendering",
                "VideoRenderingImpl",
                .product(name: "Media", package: "Media"),
                .product(name: "SpeakerAnalysis", package: "SpeakerAnalysis"),
                .product(name: "Subtitles", package: "Subtitles"),
                .product(name: "Timeline", package: "Timeline"),
            ],
            path: "Tests/VideoRenderingImplTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
