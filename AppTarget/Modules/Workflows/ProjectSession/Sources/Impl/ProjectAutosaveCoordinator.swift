import Foundation
import Project
import ProjectSession

struct ProjectPersistenceToken: Equatable {
    let projectID: UUID
    let generation: UInt
    let sequence: UInt
}

@MainActor
final class ProjectAutosaveCoordinator {
    typealias StateHandler = @MainActor (
        ProjectPersistenceToken,
        ProjectSessionPersistenceState
    ) -> Void

    private let repository: any ProjectRepository
    private let delay: Duration
    private let sleeper: ProjectSessionSleeper
    private var pendingTask: Task<Void, Never>?
    private var sequence: UInt = 0

    init(
        repository: any ProjectRepository,
        delay: Duration,
        sleeper: ProjectSessionSleeper
    ) {
        self.repository = repository
        self.delay = delay
        self.sleeper = sleeper
    }

    func schedule(
        project: Project,
        generation: UInt,
        stateHandler: @escaping StateHandler
    ) {
        let token = nextToken(projectID: project.id, generation: generation)
        pendingTask?.cancel()

        let repository = repository
        let sleeper = sleeper
        let delay = delay
        pendingTask = Task { [weak self] in
            do {
                try await sleeper.sleep(for: delay)
                try Task.checkCancellation()
                stateHandler(token, .saving(.autosave))
                try await repository.saveProject(project)
                try Task.checkCancellation()
                stateHandler(token, .saved(.autosave))
                self?.finish(token)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                stateHandler(
                    token,
                    .failed(ProjectSessionPersistenceFailure(
                        projectID: project.id,
                        saveKind: .autosave,
                        reason: .repositoryRejectedSave
                    ))
                )
                self?.finish(token)
            }
        }
    }

    func saveNow(
        project: Project,
        generation: UInt,
        stateHandler: @escaping StateHandler
    ) async {
        let token = nextToken(projectID: project.id, generation: generation)
        pendingTask?.cancel()
        pendingTask = nil
        stateHandler(token, .saving(.explicit))

        do {
            try await repository.saveProject(project)
            guard token.sequence == sequence else { return }
            stateHandler(token, .saved(.explicit))
        } catch {
            guard token.sequence == sequence else { return }
            stateHandler(
                token,
                .failed(ProjectSessionPersistenceFailure(
                    projectID: project.id,
                    saveKind: .explicit,
                    reason: .repositoryRejectedSave
                ))
            )
        }
    }

    func invalidate() {
        sequence &+= 1
        pendingTask?.cancel()
        pendingTask = nil
    }

    private func nextToken(projectID: UUID, generation: UInt) -> ProjectPersistenceToken {
        sequence &+= 1
        return ProjectPersistenceToken(
            projectID: projectID,
            generation: generation,
            sequence: sequence
        )
    }

    private func finish(_ token: ProjectPersistenceToken) {
        guard token.sequence == sequence else { return }
        pendingTask = nil
    }
}
