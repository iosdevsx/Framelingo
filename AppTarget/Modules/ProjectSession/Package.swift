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
    ],
    targets: [
        .target(
            name: "ProjectSession",
            dependencies: [
                .product(name: "Project", package: "Project"),
            ],
            path: "Sources/Api"
        ),
        .target(
            name: "ProjectSessionImpl",
            dependencies: [
                "ProjectSession",
                .product(name: "Project", package: "Project"),
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
            dependencies: ["ProjectSession", "ProjectSessionImpl"],
            path: "Tests/ImplTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
