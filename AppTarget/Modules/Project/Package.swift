// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Project",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(name: "Project", targets: ["Project"]),
        .library(name: "ProjectImpl", targets: ["ProjectImpl"]),
    ],
    dependencies: [
        .package(path: "../Shorts"),
        .package(path: "../SpeakerAnalysis"),
        .package(path: "../Subtitles"),
        .package(path: "../Timeline"),
        .package(path: "../VideoRendering"),
    ],
    targets: [
        .target(
            name: "Project",
            dependencies: [
                .product(name: "Shorts", package: "Shorts"),
                .product(name: "SpeakerAnalysis", package: "SpeakerAnalysis"),
                .product(name: "Subtitles", package: "Subtitles"),
                .product(name: "Timeline", package: "Timeline"),
                .product(name: "VideoRendering", package: "VideoRendering"),
            ],
            path: "Sources/Api"
        ),
        .target(
            name: "ProjectImpl",
            dependencies: ["Project"],
            path: "Sources/Impl"
        ),
        .testTarget(
            name: "ProjectImplTests",
            dependencies: ["Project", "ProjectImpl"],
            path: "Tests/ProjectImplTests",
            resources: [.copy("Fixtures")]
        ),
    ],
    swiftLanguageModes: [.v5]
)
