import ExportFeature
import Foundation
import Media
import Project
import Subtitles
import SwiftUI
import VideoRendering

public enum ExportFeatureAssembly {
    @MainActor
    public static func makeFactory(
        makeFFmpegService: @escaping @MainActor () -> any FFmpegService,
        subtitleScriptGenerator: any SubtitleScriptGenerating,
        mediaMetadataService: any MediaMetadataProviding,
        outputRevealer: ExportOutputRevealing,
        diagnosticCopier: ExportDiagnosticCopying,
        fileManager: FileManager = .default
    ) -> ExportFeatureFactory {
        ExportFeatureFactory(
            makeVideoSheet: { request in
                AnyView(
                    ExportVideoPresentationContainer(
                        request: request,
                        ffmpegService: makeFFmpegService(),
                        subtitleScriptGenerator: subtitleScriptGenerator,
                        mediaMetadataService: mediaMetadataService,
                        outputRevealer: outputRevealer,
                        diagnosticCopier: diagnosticCopier,
                        fileManager: fileManager
                    )
                )
            },
            makeSubtitleOptionsSheet: { request in
                AnyView(
                    SubtitleExportOptionsSheet(
                        state: request.state,
                        actions: request.actions,
                        kind: request.kind,
                        onCancel: request.cancel,
                        onExport: request.export
                    )
                )
            }
        )
    }

    @MainActor
    public static func makeActivityOverlay(
        source: ProductActivitySource,
        outputRevealer: ExportOutputRevealing,
        diagnosticCopier: ExportDiagnosticCopying
    ) -> AnyView {
        AnyView(
            ActivityToastOverlay(
                source: source,
                outputRevealer: outputRevealer,
                diagnosticCopier: diagnosticCopier
            )
        )
    }
}

@MainActor
private struct ExportVideoPresentationContainer: View {
    @StateObject private var viewModel: ExportVideoViewModel
    private let actions: VideoExportPresentationActions

    init(
        request: VideoExportPresentationRequest,
        ffmpegService: any FFmpegService,
        subtitleScriptGenerator: any SubtitleScriptGenerating,
        mediaMetadataService: any MediaMetadataProviding,
        outputRevealer: ExportOutputRevealing,
        diagnosticCopier: ExportDiagnosticCopying,
        fileManager: FileManager
    ) {
        _viewModel = StateObject(
            wrappedValue: ExportVideoViewModel(
                project: request.project,
                settings: request.project.videoExportSettings,
                ffmpegService: ffmpegService,
                subtitleScriptGenerator: subtitleScriptGenerator,
                mediaMetadataService: mediaMetadataService,
                outputRevealer: outputRevealer,
                diagnosticCopier: diagnosticCopier,
                fileManager: fileManager
            )
        )
        actions = request.actions
    }

    var body: some View {
        ExportVideoSheet(
            viewModel: viewModel,
            onStartExport: { viewModel in
                guard let outputURL = viewModel.outputURL else { return }
                actions.submit(
                    VideoExportSubmission(
                        project: viewModel.project,
                        settings: viewModel.settings,
                        sourceInfo: viewModel.sourceInfo,
                        outputURL: outputURL
                    )
                )
            }
        )
    }
}
