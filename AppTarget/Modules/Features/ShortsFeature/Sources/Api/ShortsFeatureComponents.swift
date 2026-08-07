import AVFoundation
import SwiftUI

@MainActor
public struct ShortsWorkspaceRequest {
    public let state: ShortsWorkspaceState
    public let actions: ShortsWorkspaceActions
    public let player: AVPlayer?
    public let isPlaying: Bool
    private let seekAction: (Int) -> Void
    private let togglePlaybackAction: () -> Void

    public init(
        state: ShortsWorkspaceState,
        actions: ShortsWorkspaceActions,
        player: AVPlayer?,
        isPlaying: Bool = false,
        onSeek: @escaping (Int) -> Void,
        onTogglePlayback: @escaping () -> Void = {}
    ) {
        self.state = state
        self.actions = actions
        self.player = player
        self.isPlaying = isPlaying
        self.seekAction = onSeek
        self.togglePlaybackAction = onTogglePlayback
    }

    public func seek(to milliseconds: Int) { seekAction(milliseconds) }
    public func togglePlayback() { togglePlaybackAction() }
}

@MainActor
public struct ShortsFeatureFactory {
    private let makeWorkspaceAction: (ShortsWorkspaceRequest) -> AnyView
    private let makeInspectorAction: (ShortsWorkspaceRequest) -> AnyView

    public init(
        makeWorkspace: @escaping (ShortsWorkspaceRequest) -> AnyView,
        makeInspector: @escaping (ShortsWorkspaceRequest) -> AnyView = { _ in AnyView(EmptyView()) }
    ) {
        self.makeWorkspaceAction = makeWorkspace
        self.makeInspectorAction = makeInspector
    }

    public func makeWorkspace(_ request: ShortsWorkspaceRequest) -> AnyView {
        makeWorkspaceAction(request)
    }

    /// The selected-short inspector, placed by the host BELOW the shared
    /// timeline (matching the design mock's stage → source → inspector order).
    public func makeInspector(_ request: ShortsWorkspaceRequest) -> AnyView {
        makeInspectorAction(request)
    }
}
