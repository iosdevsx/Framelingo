import Foundation

#if canImport(ffmpegkit)
import ffmpegkit

final class FFmpegKitFFmpegService: FFmpegService {
    func checkAvailability() async throws -> FFmpegInfo {
        let frameworkURL = Bundle.main.privateFrameworksURL?
            .appendingPathComponent("ffmpegkit.framework")
            ?? Bundle.main.bundleURL

        return FFmpegInfo(
            executableURL: frameworkURL,
            version: "Embedded FFmpegKit"
        )
    }

    func extractAudio(from videoURL: URL, to outputURL: URL) async throws -> URL {
        let inputAccess = videoURL.startAccessingSecurityScopedResource()
        let outputAccess = outputURL.deletingLastPathComponent().startAccessingSecurityScopedResource()
        defer {
            if inputAccess {
                videoURL.stopAccessingSecurityScopedResource()
            }
            if outputAccess {
                outputURL.deletingLastPathComponent().stopAccessingSecurityScopedResource()
            }
        }

        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        try await runFFmpeg(arguments: [
            "-y",
            "-i", videoURL.path,
            "-vn",
            "-af", "aresample=async=1:first_pts=0",
            "-acodec", "pcm_s16le",
            "-ar", "16000",
            "-ac", "1",
            outputURL.path
        ])

        return outputURL
    }

    func burnSubtitles(
        videoURL: URL,
        subtitlesURL: URL,
        outputURL: URL,
        settings: VideoExportSettings,
        sourceInfo: VideoSourceInfo?,
        clips: [ExportClipRange]?,
        progressHandler: FFmpegProgressHandler?
    ) async throws -> URL {
        let videoAccess = videoURL.startAccessingSecurityScopedResource()
        let subtitlesAccess = subtitlesURL.startAccessingSecurityScopedResource()
        let outputAccess = outputURL.deletingLastPathComponent().startAccessingSecurityScopedResource()
        defer {
            if videoAccess {
                videoURL.stopAccessingSecurityScopedResource()
            }
            if subtitlesAccess {
                subtitlesURL.stopAccessingSecurityScopedResource()
            }
            if outputAccess {
                outputURL.deletingLastPathComponent().stopAccessingSecurityScopedResource()
            }
        }

        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let targets = VideoExportGeometry.targets(settings: settings, sourceInfo: sourceInfo)

        func arguments(codecArguments: [String], includeAudio: Bool) -> [String] {
            var arguments = ["-y", "-i", videoURL.path]
            arguments += FFmpegExportArgumentsBuilder.filterArguments(
                clips: clips,
                subtitlesPath: subtitlesURL.path,
                includeAudio: includeAudio,
                targetSize: targets.size,
                targetFPS: targets.framesPerSecond
            )
            arguments += codecArguments
            arguments += FFmpegExportArgumentsBuilder.audioCodecArguments(
                clips: clips,
                includeAudio: includeAudio
            )
            arguments.append(outputURL.path)
            return arguments
        }

        func runWithAudioFallback(codecArguments: [String]) async throws {
            do {
                try await runFFmpeg(
                    arguments: arguments(codecArguments: codecArguments, includeAudio: true),
                    progressHandler: progressHandler
                )
            } catch FFmpegServiceError.processFailed(_, _, let standardError)
                where clips?.isEmpty == false
                && FFmpegExportArgumentsBuilder.indicatesMissingAudioStream(standardError) {
                try await runFFmpeg(
                    arguments: arguments(codecArguments: codecArguments, includeAudio: false),
                    progressHandler: progressHandler
                )
            }
        }

        let h264CodecArguments = [
            "-c:v", "libx264",
            "-crf", "\(settings.quality.crf)",
            "-preset", settings.preset.rawValue
        ]

        do {
            try await runWithAudioFallback(codecArguments: h264CodecArguments)
        } catch FFmpegServiceError.processFailed(_, _, let standardError) where shouldRetryWithNativeMPEG4(standardError) {
            try await runWithAudioFallback(codecArguments: [
                "-c:v", "mpeg4",
                "-q:v", "\(settings.quality.mpeg4QualityScale)"
            ])
        }

        return outputURL
    }

    private func runFFmpeg(
        arguments: [String],
        progressHandler: FFmpegProgressHandler? = nil
    ) async throws {
        // Detached at .utility: FFmpegKit's encode/burn runs for as long as the
        // media does, regardless of the caller's task priority (UI actions are
        // often .userInitiated). Pinning to .utility keeps this background work
        // from competing with interactive priority work while its continuation
        // waits on FFmpegKit's own completion callback.
        try await Task.detached(priority: .utility) {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                FFmpegKit.execute(
                    withArgumentsAsync: arguments,
                    withCompleteCallback: { session in
                        guard let session else {
                            continuation.resume(
                                throwing: FFmpegServiceError.launchFailed(
                                    executablePath: "Embedded FFmpegKit",
                                    underlyingDescription: "FFmpegKit did not return a session."
                                )
                            )
                            return
                        }

                        let output = session.getOutput() ?? ""
                        let returnCode = session.getReturnCode()

                        guard ReturnCode.isSuccess(returnCode) else {
                            continuation.resume(
                                throwing: FFmpegServiceError.processFailed(
                                    exitCode: returnCode?.getValue() ?? -1,
                                    standardOutput: output,
                                    standardError: output
                                )
                            )
                            return
                        }

                        continuation.resume()
                    },
                    withLogCallback: nil,
                    withStatisticsCallback: { statistics in
                        guard let progressHandler, let statistics else {
                            return
                        }

                        let processedTimeMs = Int(statistics.getTime())
                        guard processedTimeMs >= 0 else {
                            return
                        }

                        Task {
                            await progressHandler(processedTimeMs)
                        }
                    }
                )
            }
        }.value
    }

    private func shouldRetryWithNativeMPEG4(_ output: String) -> Bool {
        output.contains("Unrecognized option 'crf'")
            || output.contains("Unknown encoder 'libx264'")
            || output.contains("Encoder (codec h264) not found")
    }
}
#endif
