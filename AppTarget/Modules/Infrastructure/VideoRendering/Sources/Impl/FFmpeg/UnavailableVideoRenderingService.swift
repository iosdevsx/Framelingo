import Foundation
import VideoRendering

struct UnavailableFFmpegService: FFmpegService {
    func checkAvailability() async throws -> FFmpegInfo {
        throw FFmpegServiceError.notFound
    }

    func extractAudio(
        from videoURL: URL,
        to outputURL: URL,
        clips: [ExportClipRange]?
    ) async throws -> URL {
        throw FFmpegServiceError.notFound
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
        throw FFmpegServiceError.notFound
    }
}
