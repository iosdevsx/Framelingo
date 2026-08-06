import Foundation
import Project
import ProjectFeature

struct MacProductShellFailure: Error, Equatable, LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// Product navigation state. It deliberately stores identity and presentation
/// metadata, never the editable Project document owned by ProjectSession.
@MainActor
final class MacProductShell: ObservableObject {
    @Published private(set) var selectedProjectID: UUID?
    @Published private(set) var selectedProjectSummary: ProjectSummary?
    @Published private(set) var hasOpenedProject: Bool
    @Published var workspaceMode: AppWorkspaceMode {
        didSet { synchronizeProjectMode() }
    }
    @Published var projectMode: ProjectWorkspaceMode {
        didSet { synchronizeWorkspaceMode() }
    }
    @Published private(set) var isClosingProject = false
    @Published private(set) var isDeletingProject = false
    @Published private(set) var failure: MacProductShellFailure?

    private let preparedMediaCleanup: PreparedMediaCleanup
    private let projectCatalog: any ProjectCatalogManaging
    private let closeWorkspace: () -> Void
    private var selectedMediaURL: URL?
    private var isSynchronizingModes = false

    init(
        selectedProject: Project?,
        startsWorkspaceOpen: Bool = false,
        preparedMediaCleanup: PreparedMediaCleanup,
        projectCatalog: any ProjectCatalogManaging,
        closeWorkspace: @escaping () -> Void = {}
    ) {
        selectedProjectID = selectedProject?.id
        selectedProjectSummary = selectedProject.map(ProjectSummary.init)
        selectedMediaURL = selectedProject?.mediaFile.originalURL
        hasOpenedProject = startsWorkspaceOpen && selectedProject != nil
        workspaceMode = .subtitles
        projectMode = .subtitles
        self.preparedMediaCleanup = preparedMediaCleanup
        self.projectCatalog = projectCatalog
        self.closeWorkspace = closeWorkspace
    }

    func open(_ project: Project) {
        selectedProjectID = project.id
        selectedProjectSummary = ProjectSummary(project: project)
        selectedMediaURL = project.mediaFile.originalURL
        hasOpenedProject = true
        resetWorkspaceModes()
        failure = nil
    }

    func refreshSummary(from project: Project) {
        guard selectedProjectID == project.id else { return }
        selectedProjectSummary = ProjectSummary(project: project)
        selectedMediaURL = project.mediaFile.originalURL
    }

    func closeSelectedProject() async {
        guard selectedProjectID != nil,
              let mediaURL = selectedMediaURL,
              !isClosingProject else { return }

        isClosingProject = true
        failure = nil
        defer { isClosingProject = false }

        do {
            try preparedMediaCleanup.removePreparedMedia(for: mediaURL)
            clearSelection()
            closeWorkspace()
        } catch {
            failure = MacProductShellFailure(
                message: "Could not close the project because prepared media cleanup failed: \(error.localizedDescription)"
            )
        }
    }

    func deleteActiveProject() async {
        guard let projectID = selectedProjectID, !isDeletingProject else { return }

        isDeletingProject = true
        failure = nil
        defer { isDeletingProject = false }

        do {
            try await projectCatalog.delete(id: projectID)
            guard selectedProjectID == projectID else { return }
            clearSelection()
            closeWorkspace()
        } catch let error as LocalizedError {
            failure = MacProductShellFailure(
                message: error.errorDescription ?? "Could not delete the project."
            )
        } catch {
            failure = MacProductShellFailure(message: "Could not delete the project.")
        }
    }

    func clearFailure() { failure = nil }

    private func clearSelection() {
        selectedProjectID = nil
        selectedProjectSummary = nil
        selectedMediaURL = nil
        hasOpenedProject = false
        resetWorkspaceModes()
    }

    private func resetWorkspaceModes() {
        isSynchronizingModes = true
        workspaceMode = .subtitles
        projectMode = .subtitles
        isSynchronizingModes = false
    }

    private func synchronizeProjectMode() {
        guard !isSynchronizingModes else { return }
        let matchingMode: ProjectWorkspaceMode?
        switch workspaceMode {
        case .subtitles: matchingMode = .subtitles
        case .videoEditor: matchingMode = .edit
        case .shorts: matchingMode = .shorts
        case .settings: matchingMode = nil
        }
        guard let matchingMode, projectMode != matchingMode else { return }
        isSynchronizingModes = true
        projectMode = matchingMode
        isSynchronizingModes = false
    }

    private func synchronizeWorkspaceMode() {
        guard !isSynchronizingModes else { return }
        let matchingMode: AppWorkspaceMode
        switch projectMode {
        case .subtitles: matchingMode = .subtitles
        case .edit: matchingMode = .videoEditor
        case .shorts: matchingMode = .shorts
        }
        guard workspaceMode != matchingMode else { return }
        isSynchronizingModes = true
        workspaceMode = matchingMode
        isSynchronizingModes = false
    }
}
