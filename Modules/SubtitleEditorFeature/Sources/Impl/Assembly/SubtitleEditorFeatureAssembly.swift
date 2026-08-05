import Subtitles
import SubtitleEditorFeature
import SwiftUI

@MainActor
public enum SubtitleEditorFeatureAssembly {
    public static func makeCueList(
        state: SubtitleEditorState,
        actions: SubtitleEditorActions,
        focusedField: FocusState<SubtitleEditorFocus?>.Binding,
        onSeek: @escaping (Int) -> Void,
        onError: @escaping (String) -> Void
    ) -> AnyView {
        AnyView(
            CueListView(
                state: state,
                actions: actions,
                focusedField: focusedField,
                onSeek: onSeek,
                onError: onError
            )
        )
    }

    public static func makeEditorPane(
        state: SubtitleEditorState,
        actions: SubtitleEditorActions,
        onSeek: @escaping (Int) -> Void
    ) -> AnyView {
        AnyView(EditorPaneView(state: state, actions: actions, onSeek: onSeek))
    }

    public static func makeSubtitleEditor(
        state: SubtitleEditorState,
        actions: SubtitleEditorActions,
        focusedField: FocusState<SubtitleEditorFocus?>.Binding,
        onSeek: @escaping (Int) -> Void,
        onError: @escaping (String) -> Void
    ) -> AnyView {
        AnyView(
            SubtitleEditorView(
                state: state,
                actions: actions,
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
