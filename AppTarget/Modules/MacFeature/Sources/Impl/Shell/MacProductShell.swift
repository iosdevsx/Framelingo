import Combine
import Foundation
import Project
import ProjectFeature

struct MacProductShellFailure: Error, Equatable, LocalizedError {
    let message: String

    var errorDescription: String? { message }
}

@MainActor
final class MacProductShell: ObservableObject {
    @Published private(set) var selectedProject: Project?
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
    private let selectionSubject: CurrentValueSubject<Project?, Never>
    private var isSynchronizingModes = false

    init(
        selectedProject: Project?,
        startsWorkspaceOpen: Bool = false,
        preparedMediaCleanup: PreparedMediaCleanup,
        projectCatalog: any ProjectCatalogManaging
    ) {
        self.selectedProject = selectedProject
        hasOpenedProject = startsWorkspaceOpen && selectedProject != nil
        workspaceMode = .subtitles
        projectMode = .subtitles
        self.preparedMediaCleanup = preparedMediaCleanup
        self.projectCatalog = projectCatalog
        selectionSubject = CurrentValueSubject(selectedProject)
    }

    var selectionAccess: ProjectSelectionAccess {
        ProjectSelectionAccess(
            current: { [weak self] in self?.selectedProject },
            updates: { [weak self] in
                self?.selectionSubject.eraseToAnyPublisher()
                    ?? Empty<Project?, Never>().eraseToAnyPublisher()
            },
            close: { [weak self] in await self?.closeSelectedProject() }
        )
    }

    func open(_ project: Project) {
        selectedProject = project
        selectionSubject.send(project)
        hasOpenedProject = true
        resetWorkspaceModes()
        failure = nil
    }

    func updateSelectedProject(_ project: Project) {
        guard selectedProject?.id == project.id else {
            open(project)
            return
        }

        selectedProject = project
        selectionSubject.send(project)
    }

    func closeSelectedProject() async {
        guard let project = selectedProject, !isClosingProject else { return }

        isClosingProject = true
        failure = nil
        defer { isClosingProject = false }

        do {
            try preparedMediaCleanup.removePreparedMedia(for: project.mediaFile.originalURL)
            clearSelection()
        } catch {
            failure = MacProductShellFailure(
                message: "Could not close the project because prepared media cleanup failed: \(error.localizedDescription)"
            )
        }
    }

    func deleteActiveProject() async {
        guard let project = selectedProject, !isDeletingProject else { return }

        isDeletingProject = true
        failure = nil
        defer { isDeletingProject = false }

        do {
            try await projectCatalog.delete(id: project.id)
            guard selectedProject?.id == project.id else { return }
            clearSelection()
        } catch let error as LocalizedError {
            failure = MacProductShellFailure(
                message: error.errorDescription ?? "Could not delete the project."
            )
        } catch {
            failure = MacProductShellFailure(message: "Could not delete the project.")
        }
    }

    func clearFailure() {
        failure = nil
    }

    private func clearSelection() {
        selectedProject = nil
        selectionSubject.send(nil)
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
