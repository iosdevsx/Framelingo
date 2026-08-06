import ProjectDescription

public enum FramelingoPackages {
    public static let localModules: [Package.Dependency] = [
        // Composition
        .package(path: "AppTarget/Modules/Composition/MacApp"),

        // Core domain and state
        .package(path: "AppTarget/Modules/Core/Media"),
        .package(path: "AppTarget/Modules/Core/Project"),
        .package(path: "AppTarget/Modules/Core/Settings"),
        .package(path: "AppTarget/Modules/Core/Shorts"),
        .package(path: "AppTarget/Modules/Core/SpeakerAnalysis"),
        .package(path: "AppTarget/Modules/Core/Subtitles"),
        .package(path: "AppTarget/Modules/Core/Timeline"),

        // Application workflows
        .package(path: "AppTarget/Modules/Workflows/ProjectPreparation"),
        .package(path: "AppTarget/Modules/Workflows/ProjectSession"),
        .package(path: "AppTarget/Modules/Workflows/TranscriptionPipeline"),
        .package(path: "AppTarget/Modules/Workflows/TranslationPipeline"),

        // User-facing features
        .package(path: "AppTarget/Modules/Features/ExportFeature"),
        .package(path: "AppTarget/Modules/Features/HomeFeature"),
        .package(path: "AppTarget/Modules/Features/PlayerFeature"),
        .package(path: "AppTarget/Modules/Features/ProjectFeature"),
        .package(path: "AppTarget/Modules/Features/SettingsFeature"),
        .package(path: "AppTarget/Modules/Features/ShortsFeature"),
        .package(path: "AppTarget/Modules/Features/SubtitleEditorFeature"),
        .package(path: "AppTarget/Modules/Features/TimelineFeature"),

        // Platform and external-service implementations
        .package(path: "AppTarget/Modules/Infrastructure/AppUpdate"),
        .package(path: "AppTarget/Modules/Infrastructure/FFmpeg"),
        .package(path: "AppTarget/Modules/Infrastructure/SpeechToText"),
        .package(path: "AppTarget/Modules/Infrastructure/Translation"),
        .package(path: "AppTarget/Modules/Infrastructure/VideoExport"),
        .package(path: "AppTarget/Modules/Infrastructure/VideoRendering"),

        // Shared presentation primitives
        .package(path: "AppTarget/Modules/UI/DesignSystem"),
    ]
}
