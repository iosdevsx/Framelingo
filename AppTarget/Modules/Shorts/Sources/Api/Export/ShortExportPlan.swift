import Foundation
import Subtitles
import VideoRendering

public struct ShortExportPlan: Equatable, Sendable {
    public var clips: [ExportClipRange]
    public var subtitles: [SubtitleSegment]
    public var subtitleStyle: VideoExportSettings
    public var platform: ShortsPlatform
    public var reframe: VerticalReframePlan
    public var hookText: String
    public var hookFontSize: Double
    public var durationMs: Int
    public var burnSubtitlesIntoVideo: Bool
    public var writeSRTSidecar: Bool

    public init(
        clips: [ExportClipRange],
        subtitles: [SubtitleSegment],
        subtitleStyle: VideoExportSettings,
        platform: ShortsPlatform,
        reframe: VerticalReframePlan,
        hookText: String,
        hookFontSize: Double,
        durationMs: Int,
        burnSubtitlesIntoVideo: Bool,
        writeSRTSidecar: Bool
    ) {
        self.clips = clips
        self.subtitles = subtitles
        self.subtitleStyle = subtitleStyle
        self.platform = platform
        self.reframe = reframe
        self.hookText = hookText
        self.hookFontSize = hookFontSize
        self.durationMs = durationMs
        self.burnSubtitlesIntoVideo = burnSubtitlesIntoVideo
        self.writeSRTSidecar = writeSRTSidecar
    }
}
