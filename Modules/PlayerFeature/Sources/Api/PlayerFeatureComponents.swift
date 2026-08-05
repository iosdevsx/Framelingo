import AVFoundation
import Project
import SwiftUI
import VideoRendering

public struct ProjectVideoPreviewState {
    public let project: Project
    public let player: AVPlayer?
    public let isPlaying: Bool
    public let currentTimeMs: Int
    public let showsControls: Bool
    public let videoSourceInfo: VideoSourceInfo?

    public init(
        project: Project,
        player: AVPlayer?,
        isPlaying: Bool,
        currentTimeMs: Int,
        showsControls: Bool,
        videoSourceInfo: VideoSourceInfo?
    ) {
        self.project = project
        self.player = player
        self.isPlaying = isPlaying
        self.currentTimeMs = currentTimeMs
        self.showsControls = showsControls
        self.videoSourceInfo = videoSourceInfo
    }
}

@MainActor
public struct ProjectVideoPreviewActions {
    private let togglePlaybackAction: () -> Void
    private let updateSettingsAction: (VideoExportSettings, Bool) -> Void

    public init(
        togglePlayback: @escaping () -> Void,
        updateSettings: @escaping (VideoExportSettings, Bool) -> Void
    ) {
        self.togglePlaybackAction = togglePlayback
        self.updateSettingsAction = updateSettings
    }

    public func togglePlayback() {
        togglePlaybackAction()
    }

    public func updateSettings(_ settings: VideoExportSettings, registerUndo: Bool) {
        updateSettingsAction(settings, registerUndo)
    }
}

@MainActor
public struct ProjectVideoPreviewRequest {
    public let state: ProjectVideoPreviewState
    public let actions: ProjectVideoPreviewActions

    public init(state: ProjectVideoPreviewState, actions: ProjectVideoPreviewActions) {
        self.state = state
        self.actions = actions
    }
}

@MainActor
public struct PlayerFeatureFactory {
    private let makeProjectVideoPreviewAction: (ProjectVideoPreviewRequest) -> AnyView

    public init(
        makeProjectVideoPreview: @escaping (ProjectVideoPreviewRequest) -> AnyView
    ) {
        self.makeProjectVideoPreviewAction = makeProjectVideoPreview
    }

    public func makeProjectVideoPreview(_ request: ProjectVideoPreviewRequest) -> AnyView {
        makeProjectVideoPreviewAction(request)
    }
}
