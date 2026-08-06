import Subtitles
import SubtitleEditorFeature
import SwiftUI

@MainActor
public enum SubtitleEditorFeatureAssembly {
    public static func makeFactory() -> SubtitleEditorFeatureFactory {
        SubtitleEditorFeatureFactory(
            makeCueList: { request in
                AnyView(
                    CueListView(
                        state: request.state,
                        actions: request.actions,
                        focusedField: request.focusedField,
                        onSeek: request.seek,
                        onError: request.reportError
                    )
                )
            },
            makeEditorPane: { request in
                AnyView(
                    EditorPaneView(
                        state: request.state,
                        actions: request.actions,
                        onSeek: request.seek
                    )
                )
            },
            makeSubtitleEditor: { request in
                AnyView(
                    SubtitleEditorView(
                        state: request.state,
                        actions: request.actions,
                        focusedField: request.focusedField,
                        onSeek: request.seek,
                        onError: request.reportError
                    )
                )
            },
            makeImportPreview: { request in
                AnyView(
                    SubtitleImportPreviewSheet(
                        preview: request.preview,
                        hasExistingSubtitles: request.hasExistingSubtitles,
                        onCancel: request.cancel,
                        onImport: request.importSubtitles
                    )
                )
            }
        )
    }
}
