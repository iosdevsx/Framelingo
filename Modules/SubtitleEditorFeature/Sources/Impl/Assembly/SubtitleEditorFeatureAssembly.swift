import Application
import Project
import Subtitles
import SubtitleEditorFeature
import SwiftUI

@MainActor
public enum SubtitleEditorFeatureAssembly {
    public static func makeCueList(
        project: Project,
        viewModel: ProjectViewModel,
        focusedField: FocusState<SubtitleEditorFocus?>.Binding,
        onSeek: @escaping (Int) -> Void,
        onError: @escaping (String) -> Void
    ) -> AnyView {
        AnyView(
            CueListView(
                project: project,
                viewModel: viewModel,
                focusedField: focusedField,
                onSeek: onSeek,
                onError: onError
            )
        )
    }

    public static func makeEditorPane(
        project: Project,
        viewModel: ProjectViewModel,
        onSeek: @escaping (Int) -> Void
    ) -> AnyView {
        AnyView(EditorPaneView(project: project, viewModel: viewModel, onSeek: onSeek))
    }

    public static func makeSubtitleEditor(
        project: Project,
        viewModel: ProjectViewModel,
        focusedField: FocusState<SubtitleEditorFocus?>.Binding,
        onSeek: @escaping (Int) -> Void,
        onError: @escaping (String) -> Void
    ) -> AnyView {
        AnyView(
            SubtitleEditorView(
                project: project,
                viewModel: viewModel,
                focusedField: focusedField,
                onSeek: onSeek,
                onError: onError
            )
        )
    }

    public static func makeImportPreview(
        preview: SubtitleImportPreview,
        hasExistingSubtitles: Bool,
        onCancel: @escaping () -> Void,
        onImport: @escaping (SubtitleImportMode, SubtitleImportDestination) -> Void
    ) -> AnyView {
        AnyView(
            SubtitleImportPreviewSheet(
                preview: preview,
                hasExistingSubtitles: hasExistingSubtitles,
                onCancel: onCancel,
                onImport: onImport
            )
        )
    }
}
