import ExportFeature
import Media
import SwiftUI

public enum ExportFeatureAssembly {
    @MainActor
    public static func makeFactory(
        mediaMetadataService: any MediaMetadataProviding,
        outputRevealer: ExportOutputRevealing,
        diagnosticCopier: ExportDiagnosticCopying
    ) -> ExportFeatureFactory {
        ExportFeatureFactory(
            makeVideoSheet: { request in
                AnyView(
                    ExportVideoPresentationContainer(
                        request: request,
                        mediaMetadataService: mediaMetadataService,
                        outputRevealer: outputRevealer,
                        diagnosticCopier: diagnosticCopier
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
        mediaMetadataService: any MediaMetadataProviding,
        outputRevealer: ExportOutputRevealing,
        diagnosticCopier: ExportDiagnosticCopying
    ) {
        _viewModel = StateObject(
            wrappedValue: ExportVideoViewModel(
                project: request.project,
                settings: request.project.videoExportSettings,
                mediaMetadataService: mediaMetadataService,
                outputRevealer: outputRevealer,
                diagnosticCopier: diagnosticCopier
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
