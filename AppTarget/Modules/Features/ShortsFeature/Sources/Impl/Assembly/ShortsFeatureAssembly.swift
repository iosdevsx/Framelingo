import AVFoundation
import ShortsFeature
import SwiftUI

@MainActor
public enum ShortsFeatureAssembly {
    public static func makeFactory() -> ShortsFeatureFactory {
        ShortsFeatureFactory { request in
            AnyView(
                ShortsWorkspaceView(
                    state: request.state,
                    actions: request.actions,
                    player: request.player,
                    isPlaying: request.isPlaying,
                    onSeek: request.seek,
                    onTogglePlayback: request.togglePlayback
                )
            )
        }
    }
}
