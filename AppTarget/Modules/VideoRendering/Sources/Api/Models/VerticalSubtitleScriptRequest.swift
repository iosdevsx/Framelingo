import Subtitles

public struct VerticalSubtitleScriptRequest: Equatable {
    public var segments: [SubtitleSegment]
    public var style: VideoExportSettings
    public var configuration: VerticalCaptionConfiguration
    public var hookText: String
    public var hookFontSize: Double
    public var durationMs: Int

    public init(
        segments: [SubtitleSegment],
        style: VideoExportSettings,
        configuration: VerticalCaptionConfiguration,
        hookText: String,
        hookFontSize: Double,
        durationMs: Int
    ) {
        self.segments = segments
        self.style = style
        self.configuration = configuration
        self.hookText = hookText
        self.hookFontSize = hookFontSize
        self.durationMs = durationMs
    }
}
