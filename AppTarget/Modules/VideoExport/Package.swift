// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "VideoExport",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "VideoExport", targets: ["VideoExport"]),
        .library(name: "VideoExportImpl", targets: ["VideoExportImpl"]),
    ],
    dependencies: [
        .package(path: "../Media"),
        .package(path: "../Project"),
        .package(path: "../Shorts"),
        .package(path: "../SpeakerAnalysis"),
        .package(path: "../Subtitles"),
        .package(path: "../Timeline"),
        .package(path: "../VideoRendering"),
    ],
    targets: [
        .target(
            name: "VideoExport",
            dependencies: [
                .product(name: "Project", package: "Project"),
                .product(name: "Shorts", package: "Shorts"),
                .product(name: "SpeakerAnalysis", package: "SpeakerAnalysis"),
                .product(name: "Subtitles", package: "Subtitles"),
                .product(name: "VideoRendering", package: "VideoRendering"),
            ],
            path: "Sources/Api"
        ),
        .target(
            name: "VideoExportImpl",
            dependencies: [
                "VideoExport",
                .product(name: "Project", package: "Project"),
                .product(name: "Shorts", package: "Shorts"),
                .product(name: "Subtitles", package: "Subtitles"),
                .product(name: "VideoRendering", package: "VideoRendering"),
            ],
            path: "Sources/Impl"
        ),
        .testTarget(
            name: "VideoExportTests",
            dependencies: [
                "VideoExport",
                .product(name: "Media", package: "Media"),
                .product(name: "Project", package: "Project"),
                .product(name: "Subtitles", package: "Subtitles"),
                .product(name: "VideoRendering", package: "VideoRendering"),
            ],
            path: "Tests/ApiTests"
        ),
        .testTarget(
            name: "VideoExportImplTests",
            dependencies: [
                "VideoExport",
                "VideoExportImpl",
                .product(name: "Media", package: "Media"),
                .product(name: "Project", package: "Project"),
                .product(name: "Shorts", package: "Shorts"),
                .product(name: "SpeakerAnalysis", package: "SpeakerAnalysis"),
                .product(name: "Subtitles", package: "Subtitles"),
                .product(name: "Timeline", package: "Timeline"),
                .product(name: "VideoRendering", package: "VideoRendering"),
            ],
            path: "Tests/ImplTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
