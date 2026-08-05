import AVFoundation
import Application
import Project
import ShortsFeature
import SwiftUI

@MainActor
public enum ShortsFeatureAssembly {
    public static func makeWorkspace(
        project: Project,
        viewModel: ProjectViewModel,
        player: AVPlayer?,
        onSeek: @escaping (Int) -> Void
    ) -> AnyView {
        AnyView(
            ShortsWorkspaceView(
                project: project,
                viewModel: viewModel,
                player: player,
                onSeek: onSeek
            )
        )
    }
}
