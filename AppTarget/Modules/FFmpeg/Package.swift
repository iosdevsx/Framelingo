// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "FFmpeg",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(name: "FFmpeg", targets: ["FFmpeg"]),
    ],
    targets: [
        .target(
            name: "FFmpeg",
            dependencies: [
                .target(name: "ffmpegkit", condition: .when(platforms: [.macOS])),
                .target(name: "libavcodec", condition: .when(platforms: [.macOS])),
                .target(name: "libavdevice", condition: .when(platforms: [.macOS])),
                .target(name: "libavfilter", condition: .when(platforms: [.macOS])),
                .target(name: "libavformat", condition: .when(platforms: [.macOS])),
                .target(name: "libavutil", condition: .when(platforms: [.macOS])),
                .target(name: "libswresample", condition: .when(platforms: [.macOS])),
                .target(name: "libswscale", condition: .when(platforms: [.macOS])),
            ],
            path: "Sources/FFmpeg"
        ),
        .binaryTarget(name: "ffmpegkit", path: "Binaries/ffmpegkit.xcframework"),
        .binaryTarget(name: "libavcodec", path: "Binaries/libavcodec.xcframework"),
        .binaryTarget(name: "libavdevice", path: "Binaries/libavdevice.xcframework"),
        .binaryTarget(name: "libavfilter", path: "Binaries/libavfilter.xcframework"),
        .binaryTarget(name: "libavformat", path: "Binaries/libavformat.xcframework"),
        .binaryTarget(name: "libavutil", path: "Binaries/libavutil.xcframework"),
        .binaryTarget(name: "libswresample", path: "Binaries/libswresample.xcframework"),
        .binaryTarget(name: "libswscale", path: "Binaries/libswscale.xcframework"),
        .testTarget(
            name: "FFmpegTests",
            dependencies: ["FFmpeg"],
            path: "Tests/FFmpegTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
