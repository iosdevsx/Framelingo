// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Application",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(name: "Application", targets: ["Application"]),
        .library(name: "ApplicationImpl", targets: ["ApplicationImpl"]),
    ],
    dependencies: [
        .package(path: "../Media"),
        .package(path: "../Project"),
        .package(path: "../Settings"),
        .package(path: "../Shorts"),
        .package(path: "../SpeakerAnalysis"),
        .package(path: "../Subtitles"),
        .package(path: "../Translation"),
        .package(path: "../VideoRendering"),
    ],
    targets: [
        .target(
            name: "Application",
            dependencies: [
                .product(name: "Media", package: "Media"),
                .product(name: "Project", package: "Project"),
                .product(name: "Settings", package: "Settings"),
                .product(name: "Shorts", package: "Shorts"),
                .product(name: "SpeakerAnalysis", package: "SpeakerAnalysis"),
                .product(name: "Subtitles", package: "Subtitles"),
                .product(name: "Translation", package: "Translation"),
                .product(name: "VideoRendering", package: "VideoRendering"),
            ],
            path: "Sources/Api"
        ),
        .target(
            name: "ApplicationImpl",
            dependencies: [
                "Application",
                .product(name: "Project", package: "Project"),
                .product(name: "Settings", package: "Settings"),
                .product(name: "Shorts", package: "Shorts"),
                .product(name: "SpeakerAnalysis", package: "SpeakerAnalysis"),
                .product(name: "Subtitles", package: "Subtitles"),
                .product(name: "Translation", package: "Translation"),
                .product(name: "VideoRendering", package: "VideoRendering"),
            ],
            path: "Sources/Impl"
        ),
        .testTarget(
            name: "ApplicationImplTests",
            dependencies: [
                "Application",
                "ApplicationImpl",
                .product(name: "Project", package: "Project"),
                .product(name: "Settings", package: "Settings"),
                .product(name: "Shorts", package: "Shorts"),
                .product(name: "SpeakerAnalysis", package: "SpeakerAnalysis"),
                .product(name: "Subtitles", package: "Subtitles"),
                .product(name: "Translation", package: "Translation"),
                .product(name: "VideoRendering", package: "VideoRendering"),
            ],
            path: "Tests/ApplicationImplTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
