import Application
import Foundation
import Media
import Project
import Subtitles
import SwiftUI
import VideoRendering

public enum ExportFeatureAssembly {
    @MainActor
    public static func makeVideoViewModel(
        project: Project,
        settings: VideoExportSettings,
        ffmpegService: any FFmpegService,
        subtitleScriptGenerator: any SubtitleScriptGenerating,
        mediaMetadataService: any MediaMetadataProviding,
        fileManager: FileManager = .default
    ) -> ExportVideoViewModel {
        ExportVideoViewModel(
            project: project,
            settings: settings,
            ffmpegService: ffmpegService,
            subtitleScriptGenerator: subtitleScriptGenerator,
            mediaMetadataService: mediaMetadataService,
            fileManager: fileManager
        )
    }

    @MainActor
    public static func makeVideoSheet(
        viewModel: ExportVideoViewModel,
        onStartExport: @escaping (ExportVideoViewModel) -> Void
    ) -> AnyView {
        AnyView(
            ExportVideoSheet(
                viewModel: viewModel,
                onStartExport: onStartExport
            )
        )
    }

    @MainActor
    public static func makeSubtitleOptionsSheet(
        project: Project,
        viewModel: ProjectViewModel,
        kind: SubtitleExportKind,
        onCancel: @escaping () -> Void,
        onExport: @escaping () -> Void
    ) -> AnyView {
        AnyView(
            SubtitleExportOptionsSheet(
                project: project,
                viewModel: viewModel,
                kind: kind,
                onCancel: onCancel,
                onExport: onExport
            )
        )
    }

    @MainActor
    public static func makeResultView(result: MP4ExportResult) -> AnyView {
        AnyView(MP4ExportResultView(result: result))
    }

    @MainActor
    public static func makeActivityOverlay(appState: AppState) -> AnyView {
        AnyView(ActivityToastOverlay().environmentObject(appState))
    }
}
