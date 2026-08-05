import Application
import Foundation
import Media
import VideoRendering

final class DefaultProjectPreparationWorkflow: ProjectPreparationWorkflow {
    private let mediaMetadataProvider: any MediaMetadataProviding
    private let waveformLoader: any WaveformLoading
    private let makeFFmpegService: FFmpegServiceBuilder
    private let fileManager: FileManager
    private let temporaryDirectory: URL

    init(
        mediaMetadataProvider: any MediaMetadataProviding,
        waveformLoader: any WaveformLoading,
        makeFFmpegService: @escaping FFmpegServiceBuilder,
        fileManager: FileManager,
        temporaryDirectory: URL
    ) {
        self.mediaMetadataProvider = mediaMetadataProvider
        self.waveformLoader = waveformLoader
        self.makeFFmpegService = makeFFmpegService
        self.fileManager = fileManager
        self.temporaryDirectory = temporaryDirectory
    }

    func prepare(
        _ request: ProjectPreparationRequest,
        events: @escaping ProjectProcessingEventHandler
    ) async throws -> ProjectPreparationOutput {
        var project = request.project
        var sourceInfo: VideoSourceInfo?

        do {
            let metadata = try await mediaMetadataProvider.videoMetadata(for: project.mediaFile.originalURL)
            sourceInfo = VideoSourceInfo(
                width: metadata.width,
                height: metadata.height,
                nominalFrameRate: metadata.nominalFrameRate
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            sourceInfo = nil
        }

        if project.mediaFile.durationMs == nil {
            await events(.progress(value: 0.06, status: "Reading video duration..."))
            do {
                if let durationMs = try await mediaMetadataProvider.durationMs(for: project.mediaFile.originalURL) {
                    try Task.checkCancellation()
                    project.mediaFile.durationMs = durationMs
                    project.updatedAt = Date()
                    await events(.projectChanged(project))
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                await events(.progress(value: 0.08, status: "Preparing waveform..."))
            }
        }

        let audioURL = temporaryDirectory
            .appendingPathComponent("Framelingo", isDirectory: true)
            .appendingPathComponent(project.id.uuidString, isDirectory: true)
            .appendingPathComponent("waveform-\(UUID().uuidString).wav")

        do {
            let peaks = try await waveformLoader.loadWaveform(
                for: WaveformRequest(
                    projectID: project.id,
                    mediaURL: project.mediaFile.originalURL,
                    mediaSizeBytes: project.mediaFile.sizeBytes,
                    durationMs: project.mediaFile.durationMs,
                    fallbackContentEndMs: project.subtitles.map(\.endMs).max()
                ),
                audioProvider: {
                    try await self.makeFFmpegService(request.settings).extractAudio(
                        from: project.mediaFile.originalURL,
                        to: audioURL
                    )
                },
                progressHandler: { progress, status in
                    await events(.progress(value: progress, status: status))
                }
            )
            try Task.checkCancellation()
            do {
                try removeTemporaryFileIfPresent(at: audioURL)
            } catch {
                throw ProjectPreparationError.temporaryFileCleanupFailed(
                    localizedMessage(from: error, fallback: "Temporary file cleanup failed.")
                )
            }
            return ProjectPreparationOutput(
                project: project,
                waveformPeaks: peaks,
                videoSourceInfo: sourceInfo,
                status: "Project ready"
            )
        } catch is CancellationError {
            do {
                try removeTemporaryFileIfPresent(at: audioURL)
            } catch {
                throw ProjectPreparationError.cancellationAndCleanupFailed(
                    localizedMessage(from: error, fallback: "Temporary file cleanup failed.")
                )
            }
            throw CancellationError()
        } catch let error as ProjectPreparationError {
            throw error
        } catch {
            do {
                try removeTemporaryFileIfPresent(at: audioURL)
            } catch {
                return ProjectPreparationOutput(
                    project: project,
                    waveformPeaks: [],
                    videoSourceInfo: sourceInfo,
                    status: "Project ready. Waveform unavailable; temporary audio cleanup failed."
                )
            }
            return ProjectPreparationOutput(
                project: project,
                waveformPeaks: [],
                videoSourceInfo: sourceInfo,
                status: "Project ready. Waveform unavailable."
            )
        }
    }

    private func removeTemporaryFileIfPresent(at url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }

    private func localizedMessage(from error: Error, fallback: String) -> String {
        let message = (error as? LocalizedError)?.errorDescription
            ?? error.localizedDescription
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}
