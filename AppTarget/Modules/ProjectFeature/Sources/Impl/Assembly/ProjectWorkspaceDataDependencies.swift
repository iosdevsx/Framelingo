import Project
import ProjectFeature
import Settings

public struct ProjectWorkspaceDataDependencies {
    let projectRepository: any ProjectRepository
    let projectCatalog: any ProjectCatalogManaging
    let settingsAccess: SettingsAccess
    let selection: ProjectSelectionAccess

    public init(
        projectRepository: any ProjectRepository,
        projectCatalog: any ProjectCatalogManaging,
        settingsAccess: SettingsAccess,
        selection: ProjectSelectionAccess
    ) {
        self.projectRepository = projectRepository
        self.projectCatalog = projectCatalog
        self.settingsAccess = settingsAccess
        self.selection = selection
    }
}
