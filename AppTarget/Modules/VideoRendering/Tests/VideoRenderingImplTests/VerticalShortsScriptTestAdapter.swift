import Subtitles
import VideoRendering
@testable import VideoRenderingImpl

struct VerticalShortsScriptTestAdapter {
    private let generator = VideoRenderingAssembly.makeSubtitleScriptGenerator()

    func generateVerticalShortsASS(
        segments: [SubtitleSegment],
        style: VideoExportSettings,
        platform: VerticalCaptionTestPlatform,
        hookText: String,
        hookFontSize: Double,
        shortDurationMs: Int
    ) -> String {
        generator.generateVerticalASS(
            VerticalSubtitleScriptRequest(
                segments: segments,
                style: style,
                configuration: platform.configuration,
                hookText: hookText,
                hookFontSize: hookFontSize,
                durationMs: shortDurationMs
            )
        )
    }
}
