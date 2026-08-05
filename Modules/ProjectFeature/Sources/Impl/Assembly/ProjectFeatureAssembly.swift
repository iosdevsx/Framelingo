import Application
import ExportFeatureImpl
import Project
import ProjectFeature
import SwiftUI

public enum ProjectFeatureAssembly {
    @MainActor
    public static func makeView(
        appState: AppState,
        dependencies: ProjectViewModelDependencies,
        projectMode: Binding<ProjectWorkspaceMode>,
        makeExportVideoViewModel: @escaping (Project) -> ExportVideoViewModel
    ) -> some View {
        ProjectFeatureRootView(
            appState: appState,
            dependencies: dependencies,
            projectMode: projectMode,
            makeExportVideoViewModel: makeExportVideoViewModel
        )
    }
}

@MainActor
private struct ProjectFeatureRootView: View {
    @StateObject private var viewModel: ProjectViewModel
    @Binding private var projectMode: ProjectWorkspaceMode

    private let appState: AppState
    private let makeExportVideoViewModel: (Project) -> ExportVideoViewModel

    init(
        appState: AppState,
        dependencies: ProjectViewModelDependencies,
        projectMode: Binding<ProjectWorkspaceMode>,
        makeExportVideoViewModel: @escaping (Project) -> ExportVideoViewModel
    ) {
        self.appState = appState
        _viewModel = StateObject(
            wrappedValue: ProjectViewModel(
                appState: appState,
                dependencies: dependencies
            )
        )
        _projectMode = projectMode
        self.makeExportVideoViewModel = makeExportVideoViewModel
    }

    var body: some View {
        ProjectView(
            viewModel: viewModel,
            projectMode: $projectMode,
            makeExportVideoViewModel: makeExportVideoViewModel
        )
        .environmentObject(appState)
    }
}
