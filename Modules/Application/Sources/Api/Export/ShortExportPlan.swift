import Shorts
import Subtitles
import VideoRendering

/// Everything the export worker needs to render one vertical short: the
/// resolved source clip plan, cues re-timed to the short's local timeline,
/// vertical styling, reframing, and the optional hook.
struct ShortExportPlan: Sendable {
    var clips: [ExportClipRange]
    var subtitles: [SubtitleSegment]
    var subtitleStyle: VideoExportSettings
    var platform: ShortsPlatform
    var reframe: VerticalReframePlan
    var hookText: String
    var hookFontSize: Double
    var durationMs: Int
    var burnSubtitlesIntoVideo: Bool
    var writeSRTSidecar: Bool
}
