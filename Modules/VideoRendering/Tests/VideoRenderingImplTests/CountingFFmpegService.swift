import Foundation
import VideoRendering
@testable import VideoRenderingImpl

final class CountingFFmpegService: FFmpegService {
    private let counter = ExtractionCounter()

    var extractionCount: Int {
        get async { await counter.value }
    }

    func checkAvailability() async throws -> FFmpegInfo {
        FFmpegInfo(
            executableURL: URL(fileURLWithPath: "/usr/bin/false"),
            version: "test"
        )
    }

    func extractAudio(from videoURL: URL, to outputURL: URL) async throws -> URL {
        await counter.increment()
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("wav".utf8).write(to: outputURL, options: .atomic)
        return outputURL
    }

    func burnSubtitles(
        videoURL: URL,
        subtitlesURL: URL,
        outputURL: URL,
        settings: VideoExportSettings,
        sourceInfo: VideoSourceInfo?,
        clips: [ExportClipRange]?,
        verticalReframe: VerticalReframePlan?,
        progressHandler: FFmpegProgressHandler?
    ) async throws -> URL {
        outputURL
    }
}
