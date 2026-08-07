// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Settings",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(name: "Settings", targets: ["Settings"]),
        .library(name: "SettingsImpl", targets: ["SettingsImpl"]),
    ],
    dependencies: [
        .package(path: "../../Infrastructure/SpeechToText"),
        .package(path: "../Subtitles"),
    ],
    targets: [
        .target(
            name: "Settings",
            dependencies: [
                .product(name: "SpeechToText", package: "SpeechToText"),
                .product(name: "Subtitles", package: "Subtitles"),
            ],
            path: "Sources/Api"
        ),
        .target(
            name: "SettingsImpl",
            dependencies: ["Settings"],
            path: "Sources/Impl"
        ),
        .testTarget(
            name: "SettingsImplTests",
            dependencies: [
                "Settings",
                "SettingsImpl",
                .product(name: "SpeechToText", package: "SpeechToText"),
                .product(name: "Subtitles", package: "Subtitles"),
            ],
            path: "Tests/SettingsImplTests",
            resources: [.copy("Fixtures")]
        ),
    ],
    swiftLanguageModes: [.v5]
)
