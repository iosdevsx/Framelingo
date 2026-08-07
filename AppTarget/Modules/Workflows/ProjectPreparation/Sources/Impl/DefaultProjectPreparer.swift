import Foundation
import Media
import ProjectPreparation
import VideoRendering

final class DefaultProjectPreparer: ProjectPreparing {
    private let mediaMetadataProvider: any MediaMetadataProviding
    private let waveformLoader: any WaveformLoading
    private let makeFFmpegService: ProjectPreparationFFmpegServiceBuilder
    private let fileSystem: ProjectPreparationFileSystem
    private let temporaryDirectory: URL

    init(
        mediaMetadataProvider: any MediaMetadataProviding,
        waveformLoader: any WaveformLoading,
        makeFFmpegService: @escaping ProjectPreparationFFmpegServiceBuilder,
        fileSystem: ProjectPreparationFileSystem,
        temporaryDirectory: URL
    ) {
        self.mediaMetadataProvider = mediaMetadataProvider
        self.waveformLoader = waveformLoader
        self.makeFFmpegService = makeFFmpegService
        self.fileSystem = fileSystem
        self.temporaryDirectory = temporaryDirectory
    }

    func prepare(
        _ request: ProjectPreparationRequest,
        events: @escaping ProjectPreparationEventHandler
    ) async throws -> ProjectPreparationOutput {
        var project = request.project
        var sourceInfo: VideoSourceInfo?

        await events(.progress(ProjectPreparationProgress(
            phase: .readingSourceMetadata,
            fractionCompleted: 0.02
        )))
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
            await events(.progress(ProjectPreparationProgress(
                phase: .readingDuration,
                fractionCompleted: 0.06
            )))
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
                await events(.progress(ProjectPreparationProgress(
                    phase: .preparingWaveform,
                    fractionCompleted: 0.08
                )))
            }
        }

        let audioURL = temporaryAudioURL(projectID: project.id)

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
                    try await self.makeFFmpegService(request.configuration).extractAudio(
                        from: project.mediaFile.originalURL,
                        to: audioURL
                    )
                },
                progressHandler: { progress, detail in
                    await events(.progress(ProjectPreparationProgress(
                        phase: .preparingWaveform,
                        fractionCompleted: progress,
                        providerDetail: detail
                    )))
                }
            )
            try Task.checkCancellation()
            do {
                try removeTemporaryFileIfPresent(at: audioURL)
            } catch {
                throw ProjectPreparationError.temporaryAudioCleanupFailed(
                    message: localizedMessage(from: error, fallback: "Temporary file cleanup failed.")
                )
            }
            return ProjectPreparationOutput(
                project: project,
                waveformPeaks: peaks,
                videoSourceInfo: sourceInfo,
                outcome: .ready
            )
        } catch is CancellationError {
            do {
                try removeTemporaryFileIfPresent(at: audioURL)
            } catch {
                throw ProjectPreparationError.cancellationAndCleanupFailed(
                    message: localizedMessage(from: error, fallback: "Temporary file cleanup failed.")
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
                    outcome: .degraded(.waveformUnavailableAndCleanupFailed(
                        message: localizedMessage(from: error, fallback: "Temporary file cleanup failed.")
                    ))
                )
            }
            return ProjectPreparationOutput(
                project: project,
                waveformPeaks: [],
                videoSourceInfo: sourceInfo,
                outcome: .degraded(.waveformUnavailable)
            )
        }
    }

    private func temporaryAudioURL(projectID: UUID) -> URL {
        temporaryDirectory
            .appendingPathComponent("Framelingo", isDirectory: true)
            .appendingPathComponent(projectID.uuidString, isDirectory: true)
            .appendingPathComponent("waveform-\(UUID().uuidString).wav")
    }

    private func removeTemporaryFileIfPresent(at url: URL) throws {
        guard fileSystem.fileExists(url) else { return }
        try fileSystem.removeItem(url)
    }

    private func localizedMessage(from error: Error, fallback: String) -> String {
        let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}
