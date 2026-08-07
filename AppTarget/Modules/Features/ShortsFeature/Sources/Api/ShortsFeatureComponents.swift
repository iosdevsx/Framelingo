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

    public init(
        makeWorkspace: @escaping (ShortsWorkspaceRequest) -> AnyView
    ) {
        self.makeWorkspaceAction = makeWorkspace
    }

    public func makeWorkspace(_ request: ShortsWorkspaceRequest) -> AnyView {
        makeWorkspaceAction(request)
    }
}
