import Foundation

public struct FFmpegInfo: Equatable {
    public var executableURL: URL
    public var version: String

    public init(executableURL: URL, version: String) {
        self.executableURL = executableURL
        self.version = version
    }
}

public typealias FFmpegProgressHandler = @Sendable (_ processedTimeMs: Int) async -> Void

public protocol FFmpegService {
    func checkAvailability() async throws -> FFmpegInfo
    func extractAudio(from videoURL: URL, to outputURL: URL) async throws -> URL
    func burnSubtitles(
        videoURL: URL,
        subtitlesURL: URL,
        outputURL: URL,
        settings: VideoExportSettings,
        sourceInfo: VideoSourceInfo?,
        clips: [ExportClipRange]?,
        verticalReframe: VerticalReframePlan?,
        progressHandler: FFmpegProgressHandler?
    ) async throws -> URL
}

public extension FFmpegService {
    func burnSubtitles(
        videoURL: URL,
        subtitlesURL: URL,
        outputURL: URL,
        settings: VideoExportSettings,
        sourceInfo: VideoSourceInfo?,
        clips: [ExportClipRange]?,
        progressHandler: FFmpegProgressHandler?
    ) async throws -> URL {
        try await burnSubtitles(
            videoURL: videoURL,
            subtitlesURL: subtitlesURL,
            outputURL: outputURL,
            settings: settings,
            sourceInfo: sourceInfo,
            clips: clips,
            verticalReframe: nil,
            progressHandler: progressHandler
        )
    }

    func burnSubtitles(
        videoURL: URL,
        subtitlesURL: URL,
        outputURL: URL,
        settings: VideoExportSettings,
        clips: [ExportClipRange]?,
        progressHandler: FFmpegProgressHandler?
    ) async throws -> URL {
        try await burnSubtitles(
            videoURL: videoURL,
            subtitlesURL: subtitlesURL,
            outputURL: outputURL,
            settings: settings,
            sourceInfo: nil,
            clips: clips,
            progressHandler: progressHandler
        )
    }

    func burnSubtitles(
        videoURL: URL,
        subtitlesURL: URL,
        outputURL: URL,
        settings: VideoExportSettings
    ) async throws -> URL {
        try await burnSubtitles(
            videoURL: videoURL,
            subtitlesURL: subtitlesURL,
            outputURL: outputURL,
            settings: settings,
            clips: nil,
            progressHandler: nil
        )
    }

    func burnSubtitles(
        videoURL: URL,
        subtitlesURL: URL,
        outputURL: URL,
        settings: VideoExportSettings,
        progressHandler: FFmpegProgressHandler?
    ) async throws -> URL {
        try await burnSubtitles(
            videoURL: videoURL,
            subtitlesURL: subtitlesURL,
            outputURL: outputURL,
            settings: settings,
            clips: nil,
            progressHandler: progressHandler
        )
    }

    func burnSubtitles(
        videoURL: URL,
        subtitlesURL: URL,
        outputURL: URL,
        settings: VideoExportSettings,
        sourceInfo: VideoSourceInfo?
    ) async throws -> URL {
        try await burnSubtitles(
            videoURL: videoURL,
            subtitlesURL: subtitlesURL,
            outputURL: outputURL,
            settings: settings,
            sourceInfo: sourceInfo,
            clips: nil,
            progressHandler: nil
        )
    }
}
