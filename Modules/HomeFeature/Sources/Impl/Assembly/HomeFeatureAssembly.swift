import Application
import Foundation
import Media
import Project
import Subtitles
import SwiftUI

public enum HomeFeatureAssembly {
    @MainActor
    public static func makeView(
        appState: AppState,
        projectFileService: any ProjectFileServicing,
        mediaMetadataService: any MediaMetadataProviding,
        fileManager: FileManager = .default,
        mockProject: Project,
        mockSubtitles: [SubtitleSegment],
        onOpenProject: @escaping (Project) -> Void
    ) -> AnyView {
        let viewModel = HomeViewModel(
            appState: appState,
            projectFileService: projectFileService,
            mediaMetadataService: mediaMetadataService,
            fileManager: fileManager,
            mockProject: mockProject,
            mockSubtitles: mockSubtitles
        )
        return AnyView(
            HomeView(
                viewModel: viewModel,
                onOpenProject: onOpenProject
            )
        )
    }
}
