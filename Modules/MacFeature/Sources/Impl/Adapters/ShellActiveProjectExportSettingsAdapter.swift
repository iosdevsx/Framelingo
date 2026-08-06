import Foundation
import Project
import VideoRendering

/// Transitional persistence adapter for SettingsFeature. Selection remains in
/// the product shell while repository/catalog updates stay explicit.
@MainActor
final class ShellActiveProjectExportSettingsAdapter: ActiveProjectExportSettingsManaging {
    var current: VideoExportSettings? {
        shell.selectedProject?.videoExportSettings
    }

    private let shell: MacProductShell
    private let projectRepository: any ProjectRepository
    private let projectCatalog: any ProjectCatalogManaging
    private var saveTask: Task<Void, Never>?

    init(
        shell: MacProductShell,
        projectRepository: any ProjectRepository,
        projectCatalog: any ProjectCatalogManaging
    ) {
        self.shell = shell
        self.projectRepository = projectRepository
        self.projectCatalog = projectCatalog
    }

    deinit {
        saveTask?.cancel()
    }

    func update(_ settings: VideoExportSettings) {
        guard var project = shell.selectedProject else { return }

        project.videoExportSettings = settings
        project.updatedAt = Date()
        shell.updateSelectedProject(project)

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
                assertionFailure("Failed to persist active project export settings: \(error.localizedDescription)")
            }
        }
    }
}
