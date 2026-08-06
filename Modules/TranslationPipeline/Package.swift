// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TranslationPipeline",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "TranslationPipeline", targets: ["TranslationPipeline"]),
        .library(name: "TranslationPipelineImpl", targets: ["TranslationPipelineImpl"]),
    ],
    dependencies: [
        .package(path: "../Project"),
        .package(path: "../Subtitles"),
        .package(path: "../Translation"),
    ],
    targets: [
        .target(
            name: "TranslationPipeline",
            dependencies: [
                .product(name: "Project", package: "Project"),
            ],
            path: "Sources/Api"
        ),
        .target(
            name: "TranslationPipelineImpl",
            dependencies: [
                "TranslationPipeline",
                .product(name: "Project", package: "Project"),
                .product(name: "Translation", package: "Translation"),
            ],
            path: "Sources/Impl"
        ),
        .testTarget(
            name: "TranslationPipelineAPITests",
            dependencies: ["TranslationPipeline"],
            path: "Tests/TranslationPipelineAPITests"
        ),
        .testTarget(
            name: "TranslationPipelineImplTests",
            dependencies: [
                "TranslationPipeline",
                "TranslationPipelineImpl",
                .product(name: "Project", package: "Project"),
                .product(name: "Subtitles", package: "Subtitles"),
                .product(name: "Translation", package: "Translation"),
            ],
            path: "Tests/TranslationPipelineImplTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
