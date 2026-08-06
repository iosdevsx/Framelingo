import Combine
import Foundation
import HomeFeature
import Media
import Project
import Subtitles
import Testing
@testable import HomeFeatureImpl

@MainActor
struct HomeViewModelTests {
    @Test
    func projectOpeningForwardsLoadedProjectThroughNarrowContract() {
        let project = makeHomeProject(
            mediaURL: URL(fileURLWithPath: "/tmp/open.mov"),
            name: "Opened"
        )
        var openedProject: Project?
        let opening = HomeProjectOpening { openedProject = $0 }

        opening.open(project)

        #expect(openedProject?.id == project.id)
    }

    @Test
    func createRegistersCatalogOnlyAfterSuccessfulPersistence() async throws {
        let root = try makeTemporaryDirectory()
        let videoURL = root.appendingPathComponent("source.mov")
        try Data([0]).write(to: videoURL)
        let repository = HomeRepository()
        let catalog = HomeCatalog(repository: repository)
        let viewModel = makeViewModel(repository: repository, catalog: catalog)

        let createdProject = await viewModel.createProject(from: videoURL)
        let project = try #require(createdProject)

        #expect(repository.savedProjects.map(\.id) == [project.id])
        #expect(catalog.registeredProjects.map(\.id) == [project.id])
        #expect(viewModel.recentProjects.map(\.id) == [project.id])
        try FileManager.default.removeItem(at: root)
    }

    @Test
    func failedCreateSaveDoesNotRegisterCatalogSummary() async throws {
        let root = try makeTemporaryDirectory()
        let videoURL = root.appendingPathComponent("source.mov")
        try Data([0]).write(to: videoURL)
        let repository = HomeRepository(saveFailure: HomeTestError.expected)
        let catalog = HomeCatalog(repository: repository)
        let viewModel = makeViewModel(repository: repository, catalog: catalog)

        let project = await viewModel.createProject(from: videoURL)

        #expect(project == nil)
        #expect(catalog.registeredProjects.isEmpty)
        #expect(viewModel.errorMessage == "Project save failed.")
        try FileManager.default.removeItem(at: root)
    }

    @Test
    func importedProjectRegistersOnlyAfterRepositorySave() async throws {
        let root = try makeTemporaryDirectory()
        let videoURL = root.appendingPathComponent("imported.mov")
        let projectFileURL = root.appendingPathComponent("project.json")
        try Data([0]).write(to: videoURL)
        try Data([0]).write(to: projectFileURL)
        let imported = makeHomeProject(mediaURL: videoURL, name: "Imported")
        let repository = HomeRepository()
        let catalog = HomeCatalog(repository: repository)
        let viewModel = makeViewModel(
            repository: repository,
            catalog: catalog,
            projectFileService: HomeProjectFileService(project: imported)
        )

        let project = await viewModel.openProjectFile(projectFileURL)

        #expect(project?.id == imported.id)
        #expect(repository.savedProjects.map(\.id) == [imported.id])
        #expect(catalog.registeredProjects.map(\.id) == [imported.id])
        try FileManager.default.removeItem(at: root)
    }

    @Test
    func failedCatalogOpenReturnsNilAndKeepsErrorPresentable() async {
        let repository = HomeRepository()
        let catalog = HomeCatalog(
            repository: repository,
            openFailure: ProjectFileError.videoFileMissing("/missing.mov")
        )
        let project = makeHomeProject(
            mediaURL: URL(fileURLWithPath: "/missing.mov"),
            name: "Missing"
        )
        catalog.register(project)
        let viewModel = makeViewModel(repository: repository, catalog: catalog)

        let opened = await viewModel.selectProject(ProjectSummary(project: project))

        #expect(opened == nil)
        #expect(viewModel.errorMessage?.contains("source video file was not found") == true)
    }

    private func makeViewModel(
        repository: HomeRepository,
        catalog: HomeCatalog,
        projectFileService: any ProjectFileServicing = HomeProjectFileService(
            project: makeHomeProject(
                mediaURL: URL(fileURLWithPath: "/unused.mov"),
                name: "Unused"
            )
        )
    ) -> HomeViewModel {
        HomeViewModel(
            projectCatalog: catalog,
            projectRepository: repository,
            projectFileService: projectFileService,
            mediaMetadataService: HomeMetadataProvider(),
            mockProject: makeHomeProject(
                mediaURL: URL(fileURLWithPath: "/mock.mov"),
                name: "Mock"
            ),
            mockSubtitles: []
        )
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("HomeViewModelTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
        return url
    }
}

private enum HomeTestError: Error {
    case expected
}

private final class HomeRepository: ProjectRepository {
    var projects: [UUID: Project] = [:]
    var savedProjects: [Project] = []
    let saveFailure: Error?

    init(saveFailure: Error? = nil) {
        self.saveFailure = saveFailure
    }

    func createProject(for mediaFile: MediaFile) async throws -> Project {
        makeHomeProject(mediaURL: mediaFile.originalURL, name: mediaFile.fileName)
    }

    func saveProject(_ project: Project) async throws {
        if let saveFailure {
            throw saveFailure
        }
        projects[project.id] = project
        savedProjects.append(project)
    }

    func loadProject(id: UUID) async throws -> Project {
        guard let project = projects[id] else { throw HomeTestError.expected }
        return project
    }

    func listProjects() async throws -> [Project] {
        Array(projects.values)
    }

    func deleteProject(id: UUID) async throws {
        projects[id] = nil
    }
}

@MainActor
private final class HomeCatalog: ProjectCatalogManaging {
    private(set) var snapshot = ProjectCatalogSnapshot(summaries: [])
    var snapshots: AnyPublisher<ProjectCatalogSnapshot, Never> {
        subject.eraseToAnyPublisher()
    }

    private let repository: any ProjectRepository
    private let openFailure: Error?
    private let subject = CurrentValueSubject<ProjectCatalogSnapshot, Never>(
        ProjectCatalogSnapshot(summaries: [])
    )
    private(set) var registeredProjects: [Project] = []

    init(repository: any ProjectRepository, openFailure: Error? = nil) {
        self.repository = repository
        self.openFailure = openFailure
    }

    func refresh() async {
        do {
            let projects = try await repository.listProjects()
            snapshot = ProjectCatalogSnapshot(
                summaries: projects.map(ProjectSummary.init)
            )
            subject.send(snapshot)
        } catch {
            snapshot = ProjectCatalogSnapshot(
                summaries: snapshot.summaries,
                failure: ProjectCatalogFailure(
                    operation: .refresh,
                    message: error.localizedDescription
                )
            )
            subject.send(snapshot)
        }
    }

    func register(_ project: Project) {
        registeredProjects.append(project)
        snapshot = ProjectCatalogSnapshot(
            summaries: [ProjectSummary(project: project)]
        )
        subject.send(snapshot)
    }

    func open(id: UUID) async throws -> Project {
        if let openFailure { throw openFailure }
        return try await repository.loadProject(id: id)
    }

    func delete(id: UUID) async throws -> UUID {
        try await repository.deleteProject(id: id)
        return id
    }
}

private struct HomeProjectFileService: ProjectFileServicing {
    let project: Project

    func exportProject(_ project: Project, to fileURL: URL) throws {}
    func importProject(from fileURL: URL) throws -> Project { project }
}

private struct HomeMetadataProvider: MediaMetadataProviding {
    func durationMs(for url: URL) async throws -> Int? { 1_000 }
    func videoMetadata(for url: URL) async throws -> VideoMetadata {
        VideoMetadata(width: 1_920, height: 1_080, nominalFrameRate: 30)
    }
}

private func makeHomeProject(mediaURL: URL, name: String) -> Project {
    Project(
        id: UUID(),
        name: name,
        createdAt: Date(timeIntervalSince1970: 1),
        updatedAt: Date(timeIntervalSince1970: 2),
        mediaFile: MediaFile(
            id: UUID(),
            originalURL: mediaURL,
            fileName: mediaURL.lastPathComponent,
            fileExtension: mediaURL.pathExtension,
            sizeBytes: 1,
            durationMs: 1_000
        ),
        sourceLanguage: "English",
        targetLanguage: "Russian",
        subtitles: [],
        status: .ready
    )
}
