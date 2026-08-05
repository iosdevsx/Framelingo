// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "PlayerFeature",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "PlayerFeature", targets: ["PlayerFeature"]),
        .library(name: "PlayerFeatureImpl", targets: ["PlayerFeatureImpl"]),
    ],
    dependencies: [
        .package(path: "../Project"),
        .package(path: "../Subtitles"),
        .package(path: "../VideoRendering"),
    ],
    targets: [
        .target(
            name: "PlayerFeature",
            dependencies: [
                .product(name: "Project", package: "Project"),
                .product(name: "VideoRendering", package: "VideoRendering"),
            ],
            path: "Sources/Api"
        ),
        .target(
            name: "PlayerFeatureImpl",
            dependencies: [
                "PlayerFeature",
                .product(name: "Project", package: "Project"),
                .product(name: "Subtitles", package: "Subtitles"),
                .product(name: "VideoRendering", package: "VideoRendering"),
            ],
            path: "Sources/Impl"
        ),
        .testTarget(
            name: "PlayerFeatureImplTests",
            dependencies: [
                "PlayerFeature",
                "PlayerFeatureImpl",
            ],
            path: "Tests/PlayerFeatureImplTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
