import Foundation
import Project
import Subtitles
import VideoRendering

enum VideoExportWorker {
    static func run(
        project: Project,
        settings: VideoExportSettings,
        sourceInfo: VideoSourceInfo?,
        shortPlan: ShortExportPlan?,
        outputURL: URL,
        ffmpegService: any FFmpegService,
        subtitleScriptGenerator: any SubtitleScriptGenerating,
        subtitleExportService: any SubtitleExportService,
        fileManager: FileManager,
        statusHandler: @escaping @Sendable (String) async -> Void,
        progressHandler: @escaping FFmpegProgressHandler
    ) async throws {
        // A short without cues is still a valid export (video + hook only);
        // full-project export keeps requiring subtitles.
        guard shortPlan != nil || !project.subtitles.isEmpty else {
            throw ApplicationExportError.noSubtitles
        }

        guard fileManager.fileExists(atPath: project.mediaFile.originalURL.path) else {
            throw ApplicationExportError.mediaFileMissing
        }

        let clips: [ExportClipRange]?
        if let shortPlan {
            clips = shortPlan.clips
        } else {
            do {
                clips = try ExportClipPlanResolver.clips(for: project)
            } catch {
                throw ApplicationExportError.editTimelineEmpty
            }
        }

        await statusHandler("Generating subtitles...")
        let workingDirectoryURL = try temporaryExportWorkingDirectory(
            projectID: project.id,
            fileManager: fileManager
        )
        let subtitlesURL = workingDirectoryURL.appendingPathComponent("subtitles.ass")

        do {
            let ass: String
            if let shortPlan {
                ass = subtitleScriptGenerator.generateVerticalASS(
                    VerticalSubtitleScriptRequest(
                        segments: shortPlan.burnSubtitlesIntoVideo ? shortPlan.subtitles : [],
                        style: shortPlan.subtitleStyle,
                        configuration: VerticalCaptionConfiguration(
                            topSafeAreaFraction: shortPlan.platform.topSafeAreaFraction,
                            bottomSafeAreaFraction: shortPlan.platform.bottomSafeAreaFraction
                        ),
                        hookText: shortPlan.hookText,
                        hookFontSize: shortPlan.hookFontSize,
                        durationMs: shortPlan.durationMs
                    )
                )
            } else {
                ass = try subtitleScriptGenerator.generateASS(
                    segments: project.subtitles,
                    settings: settings
                )
            }
            try Data(ass.utf8).write(to: subtitlesURL, options: .atomic)
        } catch {
            throw ApplicationExportError.assGenerationFailed
        }

        await statusHandler("Exporting video...")
        _ = try await ffmpegService.burnSubtitles(
            videoURL: project.mediaFile.originalURL,
            subtitlesURL: subtitlesURL,
            outputURL: outputURL,
            settings: settings,
            sourceInfo: sourceInfo,
            clips: clips,
            verticalReframe: shortPlan?.reframe,
            progressHandler: progressHandler
        )

        if let shortPlan, shortPlan.writeSRTSidecar, !shortPlan.subtitles.isEmpty {
            await statusHandler("Writing subtitles file...")
            let request = SubtitleExportRequest(
                segments: shortPlan.subtitles,
                speakerLabels: project.speakerLabels,
                options: project.speakerExportOptions
            )
            let sidecarURL = outputURL.deletingPathExtension().appendingPathExtension("srt")
            try await subtitleExportService.exportSRT(
                request: request,
                textMode: shortPlan.subtitleStyle.subtitleTextMode,
                destinationURL: sidecarURL
            )
        }
    }

    static func failureDetails(for error: Error) -> VideoExportFailure {
        switch error {
        case FFmpegServiceError.notFound:
            return VideoExportFailure(
                message: "Embedded FFmpegKit is unavailable, and no FFmpeg executable was found.",
                debugOutput: nil
            )
        case FFmpegServiceError.processFailed(_, _, let standardError):
            let output = standardError.isEmpty ? "FFmpeg did not return stderr output." : standardError
            return VideoExportFailure(
                message: userFacingFFmpegFailureMessage(for: output),
                debugOutput: output
            )
        case let exportError as ApplicationExportError:
            return VideoExportFailure(
                message: exportError.errorDescription ?? "Video export failed.",
                debugOutput: nil
            )
        case let localizedError as LocalizedError:
            return VideoExportFailure(
                message: localizedError.errorDescription ?? "Video export failed.",
                debugOutput: nil
            )
        default:
            return VideoExportFailure(
                message: "Video export failed.",
                debugOutput: nil
            )
        }
    }

    private static func temporaryExportWorkingDirectory(
        projectID: UUID,
        fileManager: FileManager
    ) throws -> URL {
        let directoryURL = fileManager.temporaryDirectory
            .appendingPathComponent("Framelingo", isDirectory: true)
            .appendingPathComponent(projectID.uuidString, isDirectory: true)
            .appendingPathComponent("VideoExport-\(UUID().uuidString)", isDirectory: true)

        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL
    }

    private static func userFacingFFmpegFailureMessage(for output: String) -> String {
        if output.contains("No such filter: 'ass'") || output.contains("No such filter: ass") {
            return "Embedded FFmpegKit was built without the ASS subtitle filter. Rebuild FFmpegKit with libass enabled."
        }

        if output.contains("Unknown encoder 'libx264'") || output.contains("Encoder not found") {
            return "Embedded FFmpegKit was built without the H.264 encoder. Rebuild FFmpegKit with libx264 enabled."
        }

        return "Video export failed."
    }
}
