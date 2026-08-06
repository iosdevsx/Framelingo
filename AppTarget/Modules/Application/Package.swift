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
        .package(path: "../SpeakerAnalysis"),
        .package(path: "../Subtitles"),
        .package(path: "../Translation"),
    ],
    targets: [
        .target(
            name: "Application",
            dependencies: [
                .product(name: "Media", package: "Media"),
                .product(name: "SpeakerAnalysis", package: "SpeakerAnalysis"),
                .product(name: "Subtitles", package: "Subtitles"),
                .product(name: "Translation", package: "Translation"),
            ],
            path: "Sources/Api"
        ),
        .target(
            name: "ApplicationImpl",
            dependencies: [
                "Application",
            ],
            path: "Sources/Impl"
        ),
        .testTarget(
            name: "ApplicationImplTests",
            dependencies: [
                "Application",
                "ApplicationImpl",
            ],
            path: "Tests/ApplicationImplTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
