import Foundation
import Project
import Shorts
import Subtitles
import VideoExport
import VideoRendering

enum VideoExportWorkerEvent: Equatable {
    case status(VideoExport.VideoExportJobStatus, String)
    case progress(processedTimeMs: Int)
}

typealias VideoExportWorkerEventHandler = @Sendable (VideoExportWorkerEvent) async -> Void

actor VideoExportWorker {
    private let subtitleScriptGenerator: any SubtitleScriptGenerating
    private let subtitleExportService: any SubtitleExportService
    private let fileManager: FileManager

    init(
        subtitleScriptGenerator: any SubtitleScriptGenerating,
        subtitleExportService: any SubtitleExportService,
        fileManager: FileManager
    ) {
        self.subtitleScriptGenerator = subtitleScriptGenerator
        self.subtitleExportService = subtitleExportService
        self.fileManager = fileManager
    }

    func run(
        request: VideoExportRequest,
        ffmpegService: any FFmpegService,
        events: @escaping VideoExportWorkerEventHandler
    ) async -> Result<Void, VideoExportFailure> {
        do {
            try validate(request)
            let clips = try resolvedClips(for: request)
            await events(.status(.preparing, "Generating subtitles..."))
            let directory = try makeWorkingDirectory(projectID: projectID(for: request))

            do {
                try await render(
                    request: request,
                    clips: clips,
                    directory: directory,
                    ffmpegService: ffmpegService,
                    events: events
                )
            } catch {
                let failure = Self.failure(for: error)
                return .failure(cleanup(directory: directory, preserving: failure))
            }

            do {
                try fileManager.removeItem(at: directory)
                return .success(())
            } catch {
                return .failure(VideoExportFailure(
                    code: .rendering,
                    message: "Video export finished, but temporary files could not be removed.",
                    debugOutput: error.localizedDescription
                ))
            }
        } catch {
            return .failure(Self.failure(for: error))
        }
    }

    private func render(
        request: VideoExportRequest,
        clips: [ExportClipRange]?,
        directory: URL,
        ffmpegService: any FFmpegService,
        events: @escaping VideoExportWorkerEventHandler
    ) async throws {
        let subtitlesURL = directory.appendingPathComponent("subtitles.ass")
        do {
            let ass: String
            switch request {
            case .fullProject(let full):
                ass = try subtitleScriptGenerator.generateASS(
                    segments: full.project.subtitles,
                    settings: full.settings
                )
            case .short(let short):
                ass = subtitleScriptGenerator.generateVerticalASS(
                    VerticalSubtitleScriptRequest(
                        segments: short.plan.burnSubtitlesIntoVideo ? short.plan.subtitles : [],
                        style: short.plan.subtitleStyle,
                        configuration: VerticalCaptionConfiguration(
                            topSafeAreaFraction: short.plan.platform.topSafeAreaFraction,
                            bottomSafeAreaFraction: short.plan.platform.bottomSafeAreaFraction
                        ),
                        hookText: short.plan.hookText,
                        hookFontSize: short.plan.hookFontSize,
                        durationMs: short.plan.durationMs
                    )
                )
            }
            try Data(ass.utf8).write(to: subtitlesURL, options: .atomic)
        } catch {
            throw VideoExportFailure(
                code: .assGeneration,
                message: "Could not generate the subtitle file for export.",
                debugOutput: error.localizedDescription
            )
        }

        await events(.status(.exporting, "Exporting video..."))
        _ = try await ffmpegService.burnSubtitles(
            videoURL: mediaURL(for: request),
            subtitlesURL: subtitlesURL,
            outputURL: request.outputURL,
            settings: settings(for: request),
            sourceInfo: sourceInfo(for: request),
            clips: clips,
            verticalReframe: reframe(for: request),
            progressHandler: { processedTimeMs in
                await events(.progress(processedTimeMs: processedTimeMs))
            }
        )

        guard case .short(let short) = request,
              short.plan.writeSRTSidecar,
              !short.plan.subtitles.isEmpty else {
            return
        }

        await events(.status(.writingSidecar, "Writing subtitles file..."))
        do {
            try await subtitleExportService.exportSRT(
                request: SubtitleExportRequest(
                    segments: short.plan.subtitles,
                    speakerLabels: short.speakerLabels,
                    options: short.speakerExportOptions
                ),
                textMode: short.plan.subtitleStyle.subtitleTextMode,
                destinationURL: short.outputURL.deletingPathExtension().appendingPathExtension("srt")
            )
        } catch {
            throw VideoExportFailure(
                code: .sidecar,
                message: "The video was exported, but its subtitle sidecar could not be written.",
                debugOutput: error.localizedDescription
            )
        }
    }

    private func validate(_ request: VideoExportRequest) throws {
        guard fileManager.fileExists(atPath: mediaURL(for: request).path) else {
            throw VideoExportFailure(code: .missingMedia, message: "The original video file is missing.")
        }
        if case .fullProject(let full) = request, full.project.subtitles.isEmpty {
            throw VideoExportFailure(code: .missingSubtitles, message: "There are no subtitles to export.")
        }
    }

    private func resolvedClips(for request: VideoExportRequest) throws -> [ExportClipRange]? {
        switch request {
        case .short(let short):
            return short.plan.clips
        case .fullProject(let full):
            do {
                return try ExportClipPlanResolver.clips(for: full.project)
            } catch {
                throw VideoExportFailure(
                    code: .emptyTimeline,
                    message: "The edit timeline has no clips to export. Review your cuts in Edit mode."
                )
            }
        }
    }

    private func makeWorkingDirectory(projectID: UUID) throws -> URL {
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("Framelingo", isDirectory: true)
            .appendingPathComponent(projectID.uuidString, isDirectory: true)
            .appendingPathComponent("VideoExport-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func cleanup(directory: URL, preserving failure: VideoExportFailure) -> VideoExportFailure {
        do {
            try fileManager.removeItem(at: directory)
            return failure
        } catch {
            let cleanupDetails = "Temporary cleanup failed: \(error.localizedDescription)"
            let diagnostics = [failure.debugOutput, cleanupDetails]
                .compactMap { $0 }
                .joined(separator: "\n\n")
            return VideoExportFailure(
                code: failure.code,
                message: failure.message,
                debugOutput: diagnostics
            )
        }
    }

    private func projectID(for request: VideoExportRequest) -> UUID {
        switch request {
        case .fullProject(let full): full.project.id
        case .short(let short): short.projectID
        }
    }

    private func mediaURL(for request: VideoExportRequest) -> URL {
        switch request {
        case .fullProject(let full): full.project.mediaFile.originalURL
        case .short(let short): short.mediaURL
        }
    }

    private func settings(for request: VideoExportRequest) -> VideoExportSettings {
        switch request {
        case .fullProject(let full): full.settings
        case .short(let short): short.settings
        }
    }

    private func sourceInfo(for request: VideoExportRequest) -> VideoSourceInfo? {
        switch request {
        case .fullProject(let full): full.sourceInfo
        case .short(let short): short.sourceInfo
        }
    }

    private func reframe(for request: VideoExportRequest) -> VerticalReframePlan? {
        guard case .short(let short) = request else { return nil }
        return short.plan.reframe
    }

    static func failure(for error: Error) -> VideoExportFailure {
        if let failure = error as? VideoExportFailure {
            return failure
        }
        switch error {
        case FFmpegServiceError.notFound:
            return VideoExportFailure(
                code: .ffmpegUnavailable,
                message: "Embedded FFmpegKit is unavailable, and no FFmpeg executable was found."
            )
        case FFmpegServiceError.processFailed(_, _, let standardError):
            let diagnostics = standardError.isEmpty ? "FFmpeg did not return stderr output." : standardError
            if diagnostics.contains("No such filter: 'ass'") || diagnostics.contains("No such filter: ass") {
                return VideoExportFailure(
                    code: .missingASSFilter,
                    message: "Embedded FFmpegKit was built without the ASS subtitle filter. Rebuild FFmpegKit with libass enabled.",
                    debugOutput: diagnostics
                )
            }
            if diagnostics.contains("Unknown encoder 'libx264'") || diagnostics.contains("Encoder not found") {
                return VideoExportFailure(
                    code: .missingH264Encoder,
                    message: "Embedded FFmpegKit was built without the H.264 encoder. Rebuild FFmpegKit with libx264 enabled.",
                    debugOutput: diagnostics
                )
            }
            return VideoExportFailure(
                code: .rendering,
                message: "Video export failed.",
                debugOutput: diagnostics
            )
        case let localized as LocalizedError:
            return VideoExportFailure(
                code: .rendering,
                message: localized.errorDescription ?? "Video export failed."
            )
        default:
            return VideoExportFailure(code: .rendering, message: "Video export failed.")
        }
    }
}
