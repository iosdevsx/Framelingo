import Subtitles
import SwiftUI

@MainActor
public struct SubtitleCueListRequest {
    public let state: SubtitleEditorState
    public let actions: SubtitleEditorActions
    public let focusedField: FocusState<SubtitleEditorFocus?>.Binding
    private let seekAction: (Int) -> Void
    private let errorAction: (String) -> Void

    public init(
        state: SubtitleEditorState,
        actions: SubtitleEditorActions,
        focusedField: FocusState<SubtitleEditorFocus?>.Binding,
        onSeek: @escaping (Int) -> Void,
        onError: @escaping (String) -> Void
    ) {
        self.state = state
        self.actions = actions
        self.focusedField = focusedField
        self.seekAction = onSeek
        self.errorAction = onError
    }

    public func seek(to milliseconds: Int) { seekAction(milliseconds) }
    public func reportError(_ message: String) { errorAction(message) }
}

@MainActor
public struct SubtitleEditorPaneRequest {
    public let state: SubtitleEditorState
    public let actions: SubtitleEditorActions
    private let seekAction: (Int) -> Void

    public init(
        state: SubtitleEditorState,
        actions: SubtitleEditorActions,
        onSeek: @escaping (Int) -> Void
    ) {
        self.state = state
        self.actions = actions
        self.seekAction = onSeek
    }

    public func seek(to milliseconds: Int) { seekAction(milliseconds) }
}

@MainActor
public struct SubtitleEditorRequest {
    public let state: SubtitleEditorState
    public let actions: SubtitleEditorActions
    public let focusedField: FocusState<SubtitleEditorFocus?>.Binding
    private let seekAction: (Int) -> Void
    private let errorAction: (String) -> Void

    public init(
        state: SubtitleEditorState,
        actions: SubtitleEditorActions,
        focusedField: FocusState<SubtitleEditorFocus?>.Binding,
        onSeek: @escaping (Int) -> Void,
        onError: @escaping (String) -> Void
    ) {
        self.state = state
        self.actions = actions
        self.focusedField = focusedField
        self.seekAction = onSeek
        self.errorAction = onError
    }

    public func seek(to milliseconds: Int) { seekAction(milliseconds) }
    public func reportError(_ message: String) { errorAction(message) }
}

@MainActor
public struct SubtitleImportPreviewRequest {
    public let preview: SubtitleImportPreview
    public let hasExistingSubtitles: Bool
    private let cancelAction: () -> Void
    private let importAction: (SubtitleImportMode, SubtitleImportDestination) -> Void

    public init(
        preview: SubtitleImportPreview,
        hasExistingSubtitles: Bool,
        onCancel: @escaping () -> Void,
        onImport: @escaping (SubtitleImportMode, SubtitleImportDestination) -> Void
    ) {
        self.preview = preview
        self.hasExistingSubtitles = hasExistingSubtitles
        self.cancelAction = onCancel
        self.importAction = onImport
    }

    public func cancel() { cancelAction() }
    public func importSubtitles(mode: SubtitleImportMode, destination: SubtitleImportDestination) {
        importAction(mode, destination)
    }
}

@MainActor
public struct SubtitleEditorFeatureFactory {
    private let makeCueListAction: (SubtitleCueListRequest) -> AnyView
    private let makeEditorPaneAction: (SubtitleEditorPaneRequest) -> AnyView
    private let makeSubtitleEditorAction: (SubtitleEditorRequest) -> AnyView
    private let makeImportPreviewAction: (SubtitleImportPreviewRequest) -> AnyView

    public init(
        makeCueList: @escaping (SubtitleCueListRequest) -> AnyView,
        makeEditorPane: @escaping (SubtitleEditorPaneRequest) -> AnyView,
        makeSubtitleEditor: @escaping (SubtitleEditorRequest) -> AnyView,
        makeImportPreview: @escaping (SubtitleImportPreviewRequest) -> AnyView
    ) {
        self.makeCueListAction = makeCueList
        self.makeEditorPaneAction = makeEditorPane
        self.makeSubtitleEditorAction = makeSubtitleEditor
        self.makeImportPreviewAction = makeImportPreview
    }

    public func makeCueList(_ request: SubtitleCueListRequest) -> AnyView {
        makeCueListAction(request)
    }
    public func makeEditorPane(_ request: SubtitleEditorPaneRequest) -> AnyView {
        makeEditorPaneAction(request)
    }
    public func makeSubtitleEditor(_ request: SubtitleEditorRequest) -> AnyView {
        makeSubtitleEditorAction(request)
    }
    public func makeImportPreview(_ request: SubtitleImportPreviewRequest) -> AnyView {
        makeImportPreviewAction(request)
    }
}
