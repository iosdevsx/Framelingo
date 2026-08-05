import Subtitles

public protocol SubtitleScriptGenerating {
    func generateASS(
        segments: [SubtitleSegment],
        settings: VideoExportSettings
    ) throws -> String

    func generateVerticalASS(
        _ request: VerticalSubtitleScriptRequest
    ) -> String
}
