import Combine
import Foundation
import Project

@MainActor
final class DefaultProjectCatalog: ProjectCatalogManaging {
    private(set) var snapshot: ProjectCatalogSnapshot
    var snapshots: AnyPublisher<ProjectCatalogSnapshot, Never> {
        subject.eraseToAnyPublisher()
    }

    private let repository: any ProjectRepository
    private let preparedMediaCleanup: PreparedMediaCleanup
    private let subject: CurrentValueSubject<ProjectCatalogSnapshot, Never>
    private var mediaURLsByProjectID: [UUID: URL] = [:]

    init(
        repository: any ProjectRepository,
        preparedMediaCleanup: PreparedMediaCleanup,
        initialProjects: [Project] = []
    ) {
        self.repository = repository
        self.preparedMediaCleanup = preparedMediaCleanup
        let normalized = Self.normalized(initialProjects)
        snapshot = ProjectCatalogSnapshot(summaries: normalized.map(ProjectSummary.init))
        subject = CurrentValueSubject(snapshot)
        mediaURLsByProjectID = Dictionary(
            uniqueKeysWithValues: normalized.map { ($0.id, $0.mediaFile.originalURL) }
        )
    }

    func refresh() async {
        do {
            let projects = try await repository.listProjects()
            install(projects)
        } catch {
            publish(ProjectCatalogSnapshot(
                summaries: snapshot.summaries,
                failure: Self.failure(for: error, operation: .refresh)
            ))
        }
    }

    func register(_ project: Project) {
        var summaries = snapshot.summaries
        summaries.removeAll { $0.id == project.id }
        summaries.append(ProjectSummary(project: project))
        mediaURLsByProjectID[project.id] = project.mediaFile.originalURL
        publish(ProjectCatalogSnapshot(summaries: Self.sorted(summaries)))
    }

    func open(id: UUID) async throws -> Project {
        do {
            let project = try await repository.loadProject(id: id)
            mediaURLsByProjectID[id] = project.mediaFile.originalURL
            if snapshot.failure != nil {
                publish(ProjectCatalogSnapshot(summaries: snapshot.summaries))
            }
            return project
        } catch {
            publish(ProjectCatalogSnapshot(
                summaries: snapshot.summaries,
                failure: Self.failure(for: error, operation: .open)
            ))
            throw error
        }
    }

    @discardableResult
    func delete(id: UUID) async throws -> UUID {
        let mediaURL: URL
        do {
            mediaURL = try await resolveMediaURL(for: id)
        } catch {
            let failure = Self.failure(for: error, operation: .delete)
            publish(ProjectCatalogSnapshot(summaries: snapshot.summaries, failure: failure))
            throw failure
        }

        do {
            try preparedMediaCleanup.removePreparedMedia(for: mediaURL)
        } catch {
            let failure = Self.failure(for: error, operation: .cleanup)
            publish(ProjectCatalogSnapshot(summaries: snapshot.summaries, failure: failure))
            throw failure
        }

        do {
            try await repository.deleteProject(id: id)
        } catch {
            let failure = Self.failure(for: error, operation: .delete)
            publish(ProjectCatalogSnapshot(summaries: snapshot.summaries, failure: failure))
            throw failure
        }

        mediaURLsByProjectID[id] = nil
        publish(ProjectCatalogSnapshot(
            summaries: snapshot.summaries.filter { $0.id != id }
        ))
        return id
    }

    private func install(_ projects: [Project]) {
        let normalized = Self.normalized(projects)
        mediaURLsByProjectID = Dictionary(
            uniqueKeysWithValues: normalized.map { ($0.id, $0.mediaFile.originalURL) }
        )
        publish(ProjectCatalogSnapshot(summaries: normalized.map(ProjectSummary.init)))
    }

    private func resolveMediaURL(for id: UUID) async throws -> URL {
        if let mediaURL = mediaURLsByProjectID[id] {
            return mediaURL
        }

        let projects = try await repository.listProjects()
        guard let project = projects.first(where: { $0.id == id }) else {
            throw ProjectCatalogFailure(
                operation: .delete,
                message: "Project could not be found for deletion."
            )
        }
        mediaURLsByProjectID[id] = project.mediaFile.originalURL
        return project.mediaFile.originalURL
    }

    private func publish(_ snapshot: ProjectCatalogSnapshot) {
        self.snapshot = snapshot
        subject.send(snapshot)
    }

    private static func normalized(_ projects: [Project]) -> [Project] {
        var newestByID: [UUID: Project] = [:]
        for project in projects {
            if let existing = newestByID[project.id], existing.updatedAt >= project.updatedAt {
                continue
            }
            newestByID[project.id] = project
        }
        return newestByID.values.sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt {
                return lhs.id.uuidString < rhs.id.uuidString
            }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    private static func sorted(_ summaries: [ProjectSummary]) -> [ProjectSummary] {
        summaries.sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt {
                return lhs.id.uuidString < rhs.id.uuidString
            }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    private static func failure(
        for error: Error,
        operation: ProjectCatalogOperation
    ) -> ProjectCatalogFailure {
        let fallback: String
        switch operation {
        case .refresh:
            fallback = "Recent projects could not be loaded."
        case .open:
            fallback = "Project could not be opened."
        case .cleanup:
            fallback = "Prepared project media could not be removed."
        case .delete:
            fallback = "Project could not be deleted."
        }
        return ProjectCatalogFailure(
            operation: operation,
            message: (error as? LocalizedError)?.errorDescription ?? fallback
        )
    }
}
