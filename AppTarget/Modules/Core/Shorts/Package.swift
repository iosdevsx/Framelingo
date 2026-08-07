// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Shorts",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(name: "Shorts", targets: ["Shorts"]),
        .library(name: "ShortsImpl", targets: ["ShortsImpl"])
    ],
    dependencies: [
        .package(path: "../Subtitles"),
        .package(path: "../Timeline"),
        .package(path: "../../Infrastructure/VideoRendering")
    ],
    targets: [
        .target(
            name: "Shorts",
            dependencies: [
                .product(name: "Subtitles", package: "Subtitles"),
                .product(name: "Timeline", package: "Timeline"),
                .product(name: "VideoRendering", package: "VideoRendering")
            ],
            path: "Sources/Api"
        ),
        .target(
            name: "ShortsImpl",
            dependencies: [
                "Shorts",
                .product(name: "Subtitles", package: "Subtitles"),
                .product(name: "Timeline", package: "Timeline"),
                .product(name: "VideoRendering", package: "VideoRendering")
            ],
            path: "Sources/Impl"
        ),
        .testTarget(
            name: "ShortsImplTests",
            dependencies: [
                "Shorts",
                "ShortsImpl",
                .product(name: "Subtitles", package: "Subtitles"),
                .product(name: "Timeline", package: "Timeline"),
                .product(name: "VideoRendering", package: "VideoRendering")
            ],
            path: "Tests/ImplTests"
        )
    ],
    swiftLanguageModes: [.v5]
)
