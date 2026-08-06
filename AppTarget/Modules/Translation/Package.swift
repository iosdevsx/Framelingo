// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Translation",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(name: "Translation", targets: ["Translation"]),
        .library(name: "TranslationImpl", targets: ["TranslationImpl"]),
    ],
    dependencies: [
        .package(path: "../Subtitles"),
    ],
    targets: [
        .target(
            name: "Translation",
            dependencies: [
                .product(name: "Subtitles", package: "Subtitles"),
            ],
            path: "Sources/Api"
        ),
        .target(
            name: "TranslationImpl",
            dependencies: [
                "Translation",
                .product(name: "Subtitles", package: "Subtitles"),
            ],
            path: "Sources/Impl"
        ),
        .testTarget(
            name: "TranslationImplTests",
            dependencies: [
                "Translation",
                "TranslationImpl",
                .product(name: "Subtitles", package: "Subtitles"),
            ],
            path: "Tests/TranslationImplTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
