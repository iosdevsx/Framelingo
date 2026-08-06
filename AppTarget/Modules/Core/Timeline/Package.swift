// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Timeline",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(name: "Timeline", targets: ["Timeline"]),
        .library(name: "TimelineImpl", targets: ["TimelineImpl"])
    ],
    dependencies: [
        .package(path: "../Subtitles")
    ],
    targets: [
        .target(
            name: "Timeline",
            dependencies: [
                .product(name: "Subtitles", package: "Subtitles")
            ],
            path: "Sources/Api"
        ),
        .target(
            name: "TimelineImpl",
            dependencies: [
                "Timeline",
                .product(name: "Subtitles", package: "Subtitles")
            ],
            path: "Sources/Impl"
        ),
        .testTarget(
            name: "TimelineImplTests",
            dependencies: [
                "Timeline",
                "TimelineImpl",
                .product(name: "Subtitles", package: "Subtitles")
            ],
            path: "Tests/ImplTests"
        )
    ],
    swiftLanguageModes: [.v5]
)
