import Foundation
import Project
import Testing
@testable import ProjectImpl

@MainActor
struct ProjectCatalogTests {
    @Test
    func refreshDeduplicatesByIdentityAndOrdersNewestFirst() async {
        let older = makeProject(name: "Older", updatedAt: Date(timeIntervalSince1970: 10))
        var newerCopy = older
        newerCopy.name = "Newest copy"
        newerCopy.updatedAt = Date(timeIntervalSince1970: 30)
        let middle = makeProject(name: "Middle", updatedAt: Date(timeIntervalSince1970: 20))
        let repository = CatalogRepository(projects: [older, middle, newerCopy])
        let catalog = makeCatalog(repository: repository)

        await catalog.refresh()

        #expect(catalog.snapshot.summaries.map(\.id) == [newerCopy.id, middle.id])
        #expect(catalog.snapshot.summaries.first?.displayName == "Newest copy")
        #expect(catalog.snapshot.failure == nil)
    }

    @Test
    func registerUpdatesOnlySummaryAndRecalculatesOrder() {
        let repository = CatalogRepository()
        let catalog = makeCatalog(repository: repository)
        var first = makeProject(name: "First", updatedAt: Date(timeIntervalSince1970: 10))
        let second = makeProject(name: "Second", updatedAt: Date(timeIntervalSince1970: 20))
        catalog.register(first)
        catalog.register(second)
        first.name = "First updated"
        first.updatedAt = Date(timeIntervalSince1970: 30)

        catalog.register(first)

        #expect(catalog.snapshot.summaries.map(\.id) == [first.id, second.id])
        #expect(catalog.snapshot.summaries.first?.displayName == "First updated")
        #expect(catalog.snapshot.summaries.count == 2)
    }

    @Test
    func openPreservesRepositoryMissingMediaErrorAndCallerSelection() async {
        let selected = makeProject(name: "Selected")
        let missing = makeProject(name: "Missing")
        let repository = CatalogRepository(
            projects: [missing],
            loadFailure: ProjectFileError.videoFileMissing(missing.mediaFile.originalURL.path)
        )
        let catalog = makeCatalog(repository: repository)
        var callerSelection = selected

        do {
            callerSelection = try await catalog.open(id: missing.id)
            Issue.record("Expected missing-media error")
        } catch let error as ProjectFileError {
            guard case .videoFileMissing = error else {
                Issue.record("Expected videoFileMissing")
                return
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(callerSelection == selected)
        #expect(catalog.snapshot.failure?.operation == .open)
    }

    @Test
    func deleteRunsCleanupBeforeRepositoryAndRemovesSummaryAfterSuccess() async throws {
        let project = makeProject(name: "Delete")
        var cleanupCalled = false
        var repositoryObservedCleanup = false
        let repository = CatalogRepository(projects: [project])
        repository.onDelete = { repositoryObservedCleanup = cleanupCalled }
        let catalog = makeCatalog(
            repository: repository,
            cleanup: PreparedMediaCleanup { url in
                #expect(url == project.mediaFile.originalURL)
                cleanupCalled = true
            }
        )
        catalog.register(project)

        let deletedID = try await catalog.delete(id: project.id)

        #expect(deletedID == project.id)
        #expect(cleanupCalled)
        #expect(repositoryObservedCleanup)
        #expect(catalog.snapshot.summaries.isEmpty)
    }

    @Test
    func cleanupFailureKeepsSummaryAndSkipsRepositoryDeletion() async {
        let project = makeProject(name: "Cleanup failure")
        let repository = CatalogRepository(projects: [project])
        let catalog = makeCatalog(
            repository: repository,
            cleanup: PreparedMediaCleanup { _ in throw CatalogTestError.cleanup }
        )
        catalog.register(project)

        do {
            try await catalog.delete(id: project.id)
            Issue.record("Expected cleanup failure")
        } catch let failure as ProjectCatalogFailure {
            #expect(failure.operation == .cleanup)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(catalog.snapshot.summaries.map(\.id) == [project.id])
        #expect(repository.deletedIDs.isEmpty)
    }

    @Test
    func repositoryDeleteFailureKeepsSummary() async {
        let project = makeProject(name: "Delete failure")
        let repository = CatalogRepository(
            projects: [project],
            deleteFailure: CatalogTestError.delete
        )
        let catalog = makeCatalog(repository: repository)
        catalog.register(project)

        do {
            try await catalog.delete(id: project.id)
            Issue.record("Expected repository failure")
        } catch let failure as ProjectCatalogFailure {
            #expect(failure.operation == .delete)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(catalog.snapshot.summaries.map(\.id) == [project.id])
    }

    private func makeCatalog(
        repository: CatalogRepository,
        cleanup: PreparedMediaCleanup = PreparedMediaCleanup { _ in }
    ) -> DefaultProjectCatalog {
        DefaultProjectCatalog(
            repository: repository,
            preparedMediaCleanup: cleanup
        )
    }

    private func makeProject(
        name: String,
        updatedAt: Date = Date(timeIntervalSince1970: 100)
    ) -> Project {
        Project(
            id: UUID(),
            name: name,
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: updatedAt,
            mediaFile: MediaFile(
                id: UUID(),
                originalURL: URL(fileURLWithPath: "/tmp/\(name).mov"),
                fileName: "\(name).mov",
                fileExtension: "mov",
                sizeBytes: 1_024,
                durationMs: 1_000
            ),
            sourceLanguage: "English",
            targetLanguage: "Russian",
            subtitles: [],
            status: .ready
        )
    }
}

private enum CatalogTestError: Error, LocalizedError {
    case cleanup
    case delete

    var errorDescription: String? {
        switch self {
        case .cleanup: "Cleanup failed."
        case .delete: "Delete failed."
        }
    }
}

private final class CatalogRepository: ProjectRepository {
    var projects: [Project]
    var loadFailure: Error?
    var deleteFailure: Error?
    var deletedIDs: [UUID] = []
    var onDelete: () -> Void = {}

    init(
        projects: [Project] = [],
        loadFailure: Error? = nil,
        deleteFailure: Error? = nil
    ) {
        self.projects = projects
        self.loadFailure = loadFailure
        self.deleteFailure = deleteFailure
    }

    func createProject(for mediaFile: MediaFile) async throws -> Project {
        throw CatalogTestError.delete
    }

    func saveProject(_ project: Project) async throws {}

    func loadProject(id: UUID) async throws -> Project {
        if let loadFailure {
            throw loadFailure
        }
        guard let project = projects.first(where: { $0.id == id }) else {
            throw CatalogTestError.delete
        }
        return project
    }

    func listProjects() async throws -> [Project] {
        projects
    }

    func deleteProject(id: UUID) async throws {
        onDelete()
        if let deleteFailure {
            throw deleteFailure
        }
        deletedIDs.append(id)
        projects.removeAll { $0.id == id }
    }
}
