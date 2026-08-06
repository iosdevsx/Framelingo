import Combine
import Project
import ProjectFeature
import ProjectSession
import SwiftUI

@MainActor
struct MacAppScreenFactories {
    let makeHome: () -> AnyView
    let makeProject: (Binding<ProjectWorkspaceMode>) -> AnyView
    let makeSettings: () -> AnyView
    let activityOverlay: AnyView
}

/// Window-scoped state shared by every screen in one macOS workspace.
@MainActor
final class MacAppWorkspaceRuntime {
    let session: any ProjectSessionWorkspace
    let shell: MacProductShell
    private var sessionProjection: AnyCancellable?

    init(
        session: any ProjectSessionWorkspace,
        initialProject: Project?,
        preparedMediaCleanup: PreparedMediaCleanup,
        projectCatalog: any ProjectCatalogManaging
    ) {
        self.session = session
        shell = MacProductShell(
            selectedProject: initialProject,
            preparedMediaCleanup: preparedMediaCleanup,
            projectCatalog: projectCatalog,
            closeWorkspace: session.close
        )
        sessionProjection = session.snapshots
            .compactMap(\.project)
            .sink { [weak shell] project in
                shell?.refreshSummary(from: project)
                projectCatalog.register(project)
            }
    }

    func open(_ project: Project) {
        shell.open(project)
        session.open(project)
    }
}

@MainActor
struct MacAppNavigationGraph {
    let runtime: MacAppWorkspaceRuntime
    let screens: MacAppScreenFactories
}
