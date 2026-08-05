import AppKit
import Combine
import Foundation
import Media
import Project
import Subtitles
import UniformTypeIdentifiers
import VideoRendering

@MainActor
public final class ExportVideoViewModel: ObservableObject, Identifiable {
    public let id = UUID()
    public let project: Project

    @Published public var settings: VideoExportSettings
    @Published public var outputURL: URL?
    @Published public var isExporting = false
    @Published public var statusText = ""
    @Published public var errorMessage: String?
    @Published public var debugOutput: String?
    @Published public var successOutputURL: URL?
    @Published public private(set) var sourceInfo: VideoSourceInfo?
    @Published public private(set) var availableResolutions: [VideoExportResolution] = [.original]
    @Published public private(set) var availableFrameRates: [VideoExportFrameRate] = [.original]
    @Published public private(set) var isPreparingSourceInfo = true

    private let ffmpegService: any FFmpegService
    private let subtitleScriptGenerator: any SubtitleScriptGenerating
    private let mediaMetadataService: any MediaMetadataProviding
    private let fileManager: FileManager
    private var hasPreparedSourceInfo = false

    public init(
        project: Project,
        settings: VideoExportSettings = VideoExportSettings(),
        ffmpegService: any FFmpegService,
        subtitleScriptGenerator: any SubtitleScriptGenerating,
        mediaMetadataService: any MediaMetadataProviding,
        fileManager: FileManager = .default
    ) {
        self.project = project
        self.settings = settings
        self.ffmpegService = ffmpegService
        self.subtitleScriptGenerator = subtitleScriptGenerator
        self.mediaMetadataService = mediaMetadataService
        self.fileManager = fileManager
    }

    public var translatedModeHasNoText: Bool {
        settings.subtitleTextMode == .translated
            && project.subtitles.allSatisfy { $0.translatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    public func prepareForPresentation() async {
        guard !hasPreparedSourceInfo else {
            return
        }

        hasPreparedSourceInfo = true
        isPreparingSourceInfo = true

        do {
            let info = try await mediaMetadataService.videoMetadata(
                for: project.mediaFile.originalURL
            )
            sourceInfo = VideoSourceInfo(
                width: info.width,
                height: info.height,
                nominalFrameRate: info.nominalFrameRate
            )
            availableResolutions = VideoExportGeometry.availableResolutions(
                sourceWidth: info.width,
                sourceHeight: info.height
            )
            availableFrameRates = VideoExportGeometry.availableFrameRates(
                nominalFrameRate: info.nominalFrameRate
            )
        } catch {
            sourceInfo = nil
            availableResolutions = [.original]
            availableFrameRates = [.original]
        }

        if !availableResolutions.contains(settings.resolution) {
            settings.resolution = .original
        }
        if !availableFrameRates.contains(settings.frameRate) {
            settings.frameRate = .original
        }

        isPreparingSourceInfo = false
    }

    public func chooseOutputURL() {
        let panel = NSSavePanel()
        panel.title = "Export Video"
        panel.prompt = "Choose"
        panel.nameFieldStringValue = "\(project.name)_subtitled.mp4"
        panel.allowedContentTypes = [.mpeg4Movie]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        outputURL = url
    }

    public func exportVideo() async {
        guard !isExporting else {
            return
        }

        errorMessage = nil
        debugOutput = nil
        successOutputURL = nil

        do {
            guard !project.subtitles.isEmpty else {
                throw ExportVideoError.noSubtitles
            }

            guard fileManager.fileExists(atPath: project.mediaFile.originalURL.path) else {
                throw ExportVideoError.mediaFileMissing
            }

            guard let outputURL else {
                throw ExportVideoError.outputURLMissing
            }

            isExporting = true
            defer {
                isExporting = false
            }

            statusText = "Generating subtitles..."
            let workingDirectoryURL = try temporaryExportWorkingDirectory()
            let subtitlesURL = workingDirectoryURL.appendingPathComponent("subtitles.ass")

            do {
                let ass = try subtitleScriptGenerator.generateASS(
                    segments: project.subtitles,
                    settings: settings
                )
                try Data(ass.utf8).write(to: subtitlesURL, options: .atomic)
            } catch {
                throw ExportVideoError.assGenerationFailed
            }

            statusText = "Exporting video..."
            let exportedURL = try await ffmpegService.burnSubtitles(
                videoURL: project.mediaFile.originalURL,
                subtitlesURL: subtitlesURL,
                outputURL: outputURL,
                settings: settings,
                sourceInfo: sourceInfo
            )

            statusText = "Export complete."
            successOutputURL = exportedURL
        } catch let error as ExportVideoError {
            apply(error)
        } catch FFmpegServiceError.notFound {
            apply(.ffmpegFailed("Embedded FFmpegKit is unavailable, and no FFmpeg executable was found."))
        } catch FFmpegServiceError.processFailed(_, _, let standardError) {
            let output = standardError.isEmpty ? "FFmpeg did not return stderr output." : standardError
            errorMessage = userFacingFFmpegFailureMessage(for: output)
            debugOutput = output
        } catch let error as LocalizedError {
            errorMessage = error.errorDescription ?? "Video export failed."
        } catch {
            errorMessage = "Video export failed."
        }
    }

    public func revealInFinder() {
        guard let successOutputURL else {
            return
        }

        NSWorkspace.shared.activateFileViewerSelecting([successOutputURL])
    }

    private func temporaryExportWorkingDirectory() throws -> URL {
        let directoryURL = fileManager.temporaryDirectory
            .appendingPathComponent("Framelingo", isDirectory: true)
            .appendingPathComponent(project.id.uuidString, isDirectory: true)
            .appendingPathComponent("VideoExport-\(UUID().uuidString)", isDirectory: true)

        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL
    }

    private func apply(_ error: ExportVideoError) {
        errorMessage = error.errorDescription
        if case .ffmpegFailed(let stderr) = error {
            debugOutput = stderr
        }
    }

    private func userFacingFFmpegFailureMessage(for output: String) -> String {
        if output.contains("No such filter: 'ass'") || output.contains("No such filter: ass") {
            return "Embedded FFmpegKit was built without the ASS subtitle filter. Rebuild FFmpegKit with libass enabled."
        }

        if output.contains("Unknown encoder 'libx264'") || output.contains("Encoder not found") {
            return "Embedded FFmpegKit was built without the H.264 encoder. Rebuild FFmpegKit with libx264 enabled."
        }

        return "Video export failed."
    }
}

enum ExportVideoError: LocalizedError, Equatable {
    case noSubtitles
    case outputURLMissing
    case mediaFileMissing
    case assGenerationFailed
    case editTimelineEmpty
    case ffmpegFailed(String)
    case exportCancelled

    var errorDescription: String? {
        switch self {
        case .noSubtitles:
            return "There are no subtitles to export."
        case .outputURLMissing:
            return "Choose where to save the MP4 file."
        case .mediaFileMissing:
            return "The original video file is missing."
        case .assGenerationFailed:
            return "Could not generate the subtitle file for export."
        case .editTimelineEmpty:
            return "The edit timeline has no clips to export. Review your cuts in Edit mode."
        case .ffmpegFailed:
            return "Video export failed."
        case .exportCancelled:
            return "Export was cancelled."
        }
    }
}
