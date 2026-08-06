import AVFoundation
import Foundation
import PlayerFeature
import Project
import SwiftUI
import VideoRendering

@MainActor
public enum PlayerFeatureAssembly {
    public static func makeFactory() -> PlayerFeatureFactory {
        PlayerFeatureFactory { request in
            AnyView(
                ProjectVideoPreview(
                    project: request.state.project,
                    player: request.state.player,
                    isPlaying: request.state.isPlaying,
                    currentTimeMs: request.state.currentTimeMs,
                    showsControls: request.state.showsControls,
                    videoSourceInfo: request.state.videoSourceInfo,
                    onTogglePlayback: request.actions.togglePlayback,
                    onUpdateSettings: request.actions.updateSettings
                )
            )
        }
    }
}
