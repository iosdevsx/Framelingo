import Foundation
import Project
import Subtitles
import SwiftUI
import VideoRendering
import VideoExport

public struct VideoExportSubmission {
    public let project: Project
    public let settings: VideoExportSettings
    public let sourceInfo: VideoSourceInfo?
    public let outputURL: URL

    public init(
        project: Project,
        settings: VideoExportSettings,
        sourceInfo: VideoSourceInfo?,
        outputURL: URL
    ) {
        self.project = project
        self.settings = settings
        self.sourceInfo = sourceInfo
        self.outputURL = outputURL
    }

    public var request: FullProjectVideoExportRequest {
        FullProjectVideoExportRequest(
            project: project,
            settings: settings,
            sourceInfo: sourceInfo,
            outputURL: outputURL
        )
    }
}

@MainActor
public struct VideoExportPresentationActions {
    private let submitAction: (VideoExportSubmission) -> Void

    public init(submit: @escaping (VideoExportSubmission) -> Void) {
        self.submitAction = submit
    }

    public func submit(_ submission: VideoExportSubmission) {
        submitAction(submission)
    }
}

@MainActor
public struct VideoExportPresentationRequest: Identifiable {
    public let id: UUID
    public let project: Project
    public let actions: VideoExportPresentationActions

    public init(
        id: UUID = UUID(),
        project: Project,
        actions: VideoExportPresentationActions
    ) {
        self.id = id
        self.project = project
        self.actions = actions
    }
}

@MainActor
public struct SubtitleExportOptionsRequest {
    public let state: SubtitleExportOptionsState
    public let actions: SubtitleExportOptionsActions
    public let kind: SubtitleExportKind
    private let cancelAction: () -> Void
    private let exportAction: () -> Void

    public init(
        state: SubtitleExportOptionsState,
        actions: SubtitleExportOptionsActions,
        kind: SubtitleExportKind,
        onCancel: @escaping () -> Void,
        onExport: @escaping () -> Void
    ) {
        self.state = state
        self.actions = actions
        self.kind = kind
        self.cancelAction = onCancel
        self.exportAction = onExport
    }

    public func cancel() { cancelAction() }
    public func export() { exportAction() }
}

@MainActor
public struct ExportFeatureFactory {
    private let makeVideoSheetAction: (VideoExportPresentationRequest) -> AnyView
    private let makeSubtitleOptionsSheetAction: (SubtitleExportOptionsRequest) -> AnyView

    public init(
        makeVideoSheet: @escaping (VideoExportPresentationRequest) -> AnyView,
        makeSubtitleOptionsSheet: @escaping (SubtitleExportOptionsRequest) -> AnyView
    ) {
        self.makeVideoSheetAction = makeVideoSheet
        self.makeSubtitleOptionsSheetAction = makeSubtitleOptionsSheet
    }

    public func makeVideoSheet(_ request: VideoExportPresentationRequest) -> AnyView {
        makeVideoSheetAction(request)
    }

    public func makeSubtitleOptionsSheet(_ request: SubtitleExportOptionsRequest) -> AnyView {
        makeSubtitleOptionsSheetAction(request)
    }
}
