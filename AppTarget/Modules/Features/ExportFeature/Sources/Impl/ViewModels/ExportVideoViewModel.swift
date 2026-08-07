import AppKit
import Combine
import Foundation
import Media
import Project
import ExportFeature
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

    private let mediaMetadataService: any MediaMetadataProviding
    private let outputRevealer: ExportOutputRevealing
    private let diagnosticCopier: ExportDiagnosticCopying
    private var hasPreparedSourceInfo = false

    public init(
        project: Project,
        settings: VideoExportSettings = VideoExportSettings(),
        mediaMetadataService: any MediaMetadataProviding,
        outputRevealer: ExportOutputRevealing,
        diagnosticCopier: ExportDiagnosticCopying
    ) {
        self.project = project
        self.settings = settings
        self.mediaMetadataService = mediaMetadataService
        self.outputRevealer = outputRevealer
        self.diagnosticCopier = diagnosticCopier
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

    public func revealInFinder() {
        guard let successOutputURL else {
            return
        }

        if case .failure(let failure) = outputRevealer.reveal(successOutputURL) {
            errorMessage = failure.message
        }
    }

    public func copyDiagnosticText(_ text: String) {
        if case .failure(let failure) = diagnosticCopier.copy(text) {
            errorMessage = failure.message
        }
    }

}
