// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "ProjectPreparation",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "ProjectPreparation", targets: ["ProjectPreparation"]),
        .library(name: "ProjectPreparationImpl", targets: ["ProjectPreparationImpl"]),
    ],
    dependencies: [
        .package(path: "../Media"),
        .package(path: "../Project"),
        .package(path: "../VideoRendering"),
    ],
    targets: [
        .target(
            name: "ProjectPreparation",
            dependencies: [
                .product(name: "Project", package: "Project"),
                .product(name: "VideoRendering", package: "VideoRendering"),
            ],
            path: "Sources/Api"
        ),
        .target(
            name: "ProjectPreparationImpl",
            dependencies: [
                "ProjectPreparation",
                .product(name: "Media", package: "Media"),
                .product(name: "Project", package: "Project"),
                .product(name: "VideoRendering", package: "VideoRendering"),
            ],
            path: "Sources/Impl"
        ),
        .testTarget(
            name: "ProjectPreparationAPITests",
            dependencies: ["ProjectPreparation"],
            path: "Tests/ProjectPreparationAPITests"
        ),
        .testTarget(
            name: "ProjectPreparationImplTests",
            dependencies: [
                "ProjectPreparation",
                "ProjectPreparationImpl",
                .product(name: "Media", package: "Media"),
                .product(name: "Project", package: "Project"),
                .product(name: "VideoRendering", package: "VideoRendering"),
            ],
            path: "Tests/ProjectPreparationImplTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
