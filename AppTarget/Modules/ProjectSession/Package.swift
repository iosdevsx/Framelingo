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
        .package(path: "../Project"),
        .package(path: "../Shorts"),
        .package(path: "../SpeakerAnalysis"),
        .package(path: "../Subtitles"),
        .package(path: "../Timeline"),
        .package(path: "../VideoRendering"),
    ],
    targets: [
        .target(
            name: "ProjectSession",
            dependencies: [
                .product(name: "Project", package: "Project"),
                .product(name: "Shorts", package: "Shorts"),
                .product(name: "Subtitles", package: "Subtitles"),
                .product(name: "Timeline", package: "Timeline"),
                .product(name: "VideoRendering", package: "VideoRendering"),
            ],
            path: "Sources/Api"
        ),
        .target(
            name: "ProjectSessionImpl",
            dependencies: [
                "ProjectSession",
                .product(name: "Project", package: "Project"),
                .product(name: "Shorts", package: "Shorts"),
                .product(name: "Subtitles", package: "Subtitles"),
                .product(name: "Timeline", package: "Timeline"),
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
                .product(name: "TimelineImpl", package: "Timeline"),
            ],
            path: "Tests/ImplTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
