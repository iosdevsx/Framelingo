import AVFoundation
import ShortsFeature
import SwiftUI

@MainActor
public enum ShortsFeatureAssembly {
    public static func makeWorkspace(
        state: ShortsWorkspaceState,
        actions: ShortsWorkspaceActions,
        player: AVPlayer?,
        onSeek: @escaping (Int) -> Void
    ) -> AnyView {
        AnyView(
            ShortsWorkspaceView(
                state: state,
                actions: actions,
                player: player,
                onSeek: onSeek
            )
        )
    }
}
