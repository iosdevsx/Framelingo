// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SpeechToText",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(name: "SpeechToText", targets: ["SpeechToText"]),
        .library(name: "SpeechToTextImpl", targets: ["SpeechToTextImpl"]),
    ],
    dependencies: [
        .package(path: "../../Core/SpeakerAnalysis"),
        .package(path: "../../Core/Subtitles"),
        .package(url: "https://github.com/FluidInference/FluidAudio.git", exact: "0.14.1"),
    ],
    targets: [
        .target(
            name: "SpeechToText",
            dependencies: [
                .product(name: "SpeakerAnalysis", package: "SpeakerAnalysis"),
                .product(name: "Subtitles", package: "Subtitles"),
            ],
            path: "Sources/Api"
        ),
        .target(
            name: "SpeechToTextImpl",
            dependencies: [
                "SpeechToText",
                .product(name: "FluidAudio", package: "FluidAudio"),
                .product(name: "SpeakerAnalysis", package: "SpeakerAnalysis"),
                .product(name: "Subtitles", package: "Subtitles"),
            ],
            path: "Sources/Impl"
        ),
        .testTarget(
            name: "SpeechToTextImplTests",
            dependencies: [
                "SpeechToText",
                "SpeechToTextImpl",
                .product(name: "FluidAudio", package: "FluidAudio"),
                .product(name: "SpeakerAnalysis", package: "SpeakerAnalysis"),
                .product(name: "Subtitles", package: "Subtitles"),
            ],
            path: "Tests/SpeechToTextImplTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
