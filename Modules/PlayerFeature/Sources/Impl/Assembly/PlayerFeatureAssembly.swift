import AVFoundation
import Foundation
import PlayerFeature
import Project
import SwiftUI
import VideoRendering

@MainActor
public enum PlayerFeatureAssembly {
    public static func makeProjectVideoPreview(
        project: Project,
        player: AVPlayer?,
        isPlaying: Bool,
        currentTimeMs: Int,
        showsControls: Bool,
        videoSourceInfo: VideoSourceInfo?,
        onTogglePlayback: @escaping () -> Void,
        onUpdateSettings: @escaping (VideoExportSettings, Bool) -> Void
    ) -> AnyView {
        AnyView(
            ProjectVideoPreview(
                project: project,
                player: player,
                isPlaying: isPlaying,
                currentTimeMs: currentTimeMs,
                showsControls: showsControls,
                videoSourceInfo: videoSourceInfo,
                onTogglePlayback: onTogglePlayback,
                onUpdateSettings: onUpdateSettings
            )
        )
    }
}
