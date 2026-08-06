import Foundation
import Project

public enum ProjectAssembly {
    @MainActor
    public static func makeCatalog(
        repository: any ProjectRepository,
        preparedMediaCleanup: PreparedMediaCleanup
    ) -> any ProjectCatalogManaging {
        DefaultProjectCatalog(
            repository: repository,
            preparedMediaCleanup: preparedMediaCleanup
        )
    }

    public static func makeRepository(
        fileManager: FileManager = .default,
        appName: String = "Framelingo"
    ) -> any ProjectRepository {
        FileProjectRepository(fileManager: fileManager, appName: appName)
    }

    public static func makeRepository(
        fileManager: FileManager = .default,
        projectsDirectory: URL
    ) -> any ProjectRepository {
        FileProjectRepository(
            fileManager: fileManager,
            projectsDirectory: projectsDirectory
        )
    }

    public static func makeFileService() -> any ProjectFileServicing {
        ProjectFileService()
    }
}
