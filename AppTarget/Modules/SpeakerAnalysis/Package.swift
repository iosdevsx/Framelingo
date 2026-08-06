// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SpeakerAnalysis",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(name: "SpeakerAnalysis", targets: ["SpeakerAnalysis"]),
        .library(name: "SpeakerAnalysisImpl", targets: ["SpeakerAnalysisImpl"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/FluidInference/FluidAudio.git",
            exact: "0.14.1"
        ),
    ],
    targets: [
        .target(
            name: "SpeakerAnalysis",
            path: "Sources/Api"
        ),
        .target(
            name: "SpeakerAnalysisImpl",
            dependencies: [
                "SpeakerAnalysis",
                .product(name: "FluidAudio", package: "FluidAudio"),
            ],
            path: "Sources/Impl"
        ),
        .testTarget(
            name: "SpeakerAnalysisImplTests",
            dependencies: ["SpeakerAnalysis", "SpeakerAnalysisImpl"],
            path: "Tests/SpeakerAnalysisImplTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
