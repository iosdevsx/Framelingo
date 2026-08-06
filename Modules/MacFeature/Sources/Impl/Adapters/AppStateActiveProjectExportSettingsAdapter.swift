import Application
import Foundation
import Project
import VideoRendering

/// Transitional adapter until active-project ownership moves from AppState to
/// the product shell. It stages the selected Project immediately and owns the
/// existing 400 ms persistence debounce for settings-screen edits.
@MainActor
final class AppStateActiveProjectExportSettingsAdapter: ActiveProjectExportSettingsManaging {
    var current: VideoExportSettings? {
        appState.selectedProject?.videoExportSettings
    }

    private let appState: AppState
    private let projectRepository: any ProjectRepository
    private let projectCatalog: any ProjectCatalogManaging
    private var saveTask: Task<Void, Never>?

    init(
        appState: AppState,
        projectRepository: any ProjectRepository,
        projectCatalog: any ProjectCatalogManaging
    ) {
        self.appState = appState
        self.projectRepository = projectRepository
        self.projectCatalog = projectCatalog
    }

    deinit {
        saveTask?.cancel()
    }

    func update(_ settings: VideoExportSettings) {
        guard var project = appState.selectedProject else {
            return
        }

        project.videoExportSettings = settings
        project.updatedAt = Date()
        appState.selectedProject = project

        saveTask?.cancel()
        let repository = projectRepository
        let catalog = projectCatalog
        saveTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(400))
                try Task.checkCancellation()
                try await repository.saveProject(project)
                catalog.register(project)
            } catch is CancellationError {
                return
            } catch {
                assertionFailure("Project export settings could not be saved: \(error.localizedDescription)")
            }
        }
    }
}
