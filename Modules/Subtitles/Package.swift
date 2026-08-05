// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Subtitles",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(name: "Subtitles", targets: ["Subtitles"]),
        .library(name: "SubtitlesImpl", targets: ["SubtitlesImpl"]),
    ],
    dependencies: [
        .package(path: "../SpeakerAnalysis"),
    ],
    targets: [
        .target(
            name: "Subtitles",
            dependencies: ["SpeakerAnalysis"],
            path: "Sources/Api"
        ),
        .target(
            name: "SubtitlesImpl",
            dependencies: ["Subtitles"],
            path: "Sources/Impl"
        ),
        .testTarget(
            name: "SubtitlesImplTests",
            dependencies: [
                "Subtitles",
                "SubtitlesImpl",
                .product(name: "SpeakerAnalysis", package: "SpeakerAnalysis"),
            ],
            path: "Tests/SubtitlesImplTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
