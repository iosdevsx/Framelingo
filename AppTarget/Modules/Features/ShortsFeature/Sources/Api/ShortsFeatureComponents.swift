import AVFoundation
import SwiftUI

@MainActor
public struct ShortsWorkspaceRequest {
    public let state: ShortsWorkspaceState
    public let actions: ShortsWorkspaceActions
    public let player: AVPlayer?
    private let seekAction: (Int) -> Void

    public init(
        state: ShortsWorkspaceState,
        actions: ShortsWorkspaceActions,
        player: AVPlayer?,
        onSeek: @escaping (Int) -> Void
    ) {
        self.state = state
        self.actions = actions
        self.player = player
        self.seekAction = onSeek
    }

    public func seek(to milliseconds: Int) { seekAction(milliseconds) }
}

@MainActor
public struct ShortsFeatureFactory {
    private let makeWorkspaceAction: (ShortsWorkspaceRequest) -> AnyView

    public init(makeWorkspace: @escaping (ShortsWorkspaceRequest) -> AnyView) {
        self.makeWorkspaceAction = makeWorkspace
    }

    public func makeWorkspace(_ request: ShortsWorkspaceRequest) -> AnyView {
        makeWorkspaceAction(request)
    }
}
