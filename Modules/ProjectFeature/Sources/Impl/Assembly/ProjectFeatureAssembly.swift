import Application
import ExportFeatureImpl
import Project
import ProjectFeature
import SwiftUI

public enum ProjectFeatureAssembly {
    @MainActor
    public static func makeView(
        appState: AppState,
        viewModel: ProjectViewModel,
        projectMode: Binding<ProjectWorkspaceMode>,
        makeExportVideoViewModel: @escaping (Project) -> ExportVideoViewModel
    ) -> AnyView {
        AnyView(
            ProjectView(
                viewModel: viewModel,
                projectMode: projectMode,
                makeExportVideoViewModel: makeExportVideoViewModel
            )
            .environmentObject(appState)
        )
    }
}
