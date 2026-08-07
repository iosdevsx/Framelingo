import Foundation
import HomeFeature
import Media
import Project
import Subtitles
import SwiftUI

public enum HomeFeatureAssembly {
    @MainActor
    public static func makeView(
        projectCatalog: any ProjectCatalogManaging,
        projectRepository: any ProjectRepository,
        projectFileService: any ProjectFileServicing,
        mediaMetadataService: any MediaMetadataProviding,
        fileManager: FileManager = .default,
        mockProject: Project,
        mockSubtitles: [SubtitleSegment],
        projectOpening: HomeProjectOpening
    ) -> AnyView {
        let viewModel = HomeViewModel(
            projectCatalog: projectCatalog,
            projectRepository: projectRepository,
            projectFileService: projectFileService,
            mediaMetadataService: mediaMetadataService,
            fileManager: fileManager,
            mockProject: mockProject,
            mockSubtitles: mockSubtitles
        )
        return AnyView(
            HomeView(
                viewModel: viewModel,
                onOpenProject: projectOpening.open
            )
        )
    }
}
