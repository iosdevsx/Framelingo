import Combine
import Foundation
import Project
import ProjectSession

enum ProjectSessionHistoryPolicy: Sendable {
    case none
    case undoable
}

enum ProjectSessionPersistencePolicy: Sendable {
    case none
    case autosave
}

struct ProjectSessionTransactionMetadata: Sendable {
    let history: ProjectSessionHistoryPolicy
    let persistence: ProjectSessionPersistencePolicy
    let eventKind: ProjectSessionDocumentChangeKind

    static let undoable = ProjectSessionTransactionMetadata(
        history: .undoable,
        persistence: .autosave,
        eventKind: .changed
    )
}

@MainActor
public final class DefaultProjectSession: ProjectSession {
    public private(set) var snapshot: ProjectSessionSnapshot {
        didSet { snapshotSubject.send(snapshot) }
    }

    public var snapshots: AnyPublisher<ProjectSessionSnapshot, Never> {
        snapshotSubject.eraseToAnyPublisher()
    }

    public var activeProjectID: UUID? { project?.id }

    private var project: Project?
    private var history: ProjectSessionHistory
    private var persistenceState: ProjectSessionPersistenceState = .idle
    private var generation: UInt = 0
    private let documentChangeSink: ProjectSessionDocumentChangeSink
    private let now: @MainActor () -> Date
    private let autosave: ProjectAutosaveCoordinator
    private let snapshotSubject: CurrentValueSubject<ProjectSessionSnapshot, Never>

    public init(dependencies: ProjectSessionDependencies) {
        let initialSnapshot = ProjectSessionSnapshot(
            project: nil,
            history: .empty,
            persistence: .idle
        )
        snapshot = initialSnapshot
        snapshotSubject = CurrentValueSubject(initialSnapshot)
        history = ProjectSessionHistory(limit: dependencies.historyLimit)
        documentChangeSink = dependencies.documentChangeSink
        now = dependencies.now
        autosave = ProjectAutosaveCoordinator(
            repository: dependencies.repository,
            delay: dependencies.autosaveDelay,
            sleeper: dependencies.sleeper
        )
    }

    public func open(_ project: Project) {
        autosave.invalidate()
        history.reset()
        generation &+= 1
        self.project = project
        persistenceState = .idle
        publishSnapshot()
        sendDocumentEvent(kind: .opened)
    }

    public func close() {
        guard project != nil else { return }
        autosave.invalidate()
        history.reset()
        generation &+= 1
        project = nil
        persistenceState = .idle
        publishSnapshot()
        sendDocumentEvent(kind: .closed)
    }

    public func undo() {
        guard let current = project,
              let previous = history.undo(current: current) else { return }

        _ = install(
            candidate: previous,
            metadata: ProjectSessionTransactionMetadata(
                history: .none,
                persistence: .autosave,
                eventKind: .undo
            )
        )
    }

    public func redo() {
        guard let current = project,
              let next = history.redo(current: current) else { return }

        _ = install(
            candidate: next,
            metadata: ProjectSessionTransactionMetadata(
                history: .none,
                persistence: .autosave,
                eventKind: .redo
            )
        )
    }

    public func beginInteraction(named name: String) {
        guard let project else { return }
        history.beginInteraction(named: name, project: project)
    }

    public func endInteraction(named name: String) {
        guard let project,
              history.endInteraction(named: name, currentProject: project) else { return }
        publishSnapshot()
    }

    public func save() async {
        guard let project else { return }
        await autosave.saveNow(
            project: project,
            generation: generation,
            stateHandler: persistenceStateHandler
        )
    }

    @discardableResult
    func install(
        candidate: Project,
        metadata: ProjectSessionTransactionMetadata = .undoable,
        validate: (Project) -> Bool = { _ in true }
    ) -> Bool {
        guard let previous = project,
              candidate.id == previous.id,
              validate(candidate) else {
            return false
        }

        var installed = candidate
        installed.updatedAt = previous.updatedAt
        guard installed != previous else { return false }

        if case .undoable = metadata.history {
            history.record(previous: previous)
        }

        installed.updatedAt = now()
        project = installed
        persistenceState = .idle
        publishSnapshot()
        sendDocumentEvent(kind: metadata.eventKind)

        if case .autosave = metadata.persistence {
            autosave.schedule(
                project: installed,
                generation: generation,
                stateHandler: persistenceStateHandler
            )
        }
        return true
    }

    private var persistenceStateHandler: ProjectAutosaveCoordinator.StateHandler {
        { [weak self] token, state in
            guard let self,
                  self.project?.id == token.projectID,
                  self.generation == token.generation else { return }
            self.persistenceState = state
            self.publishSnapshot()
        }
    }

    private func publishSnapshot() {
        snapshot = ProjectSessionSnapshot(
            project: project,
            history: ProjectSessionHistoryState(
                canUndo: history.canUndo,
                canRedo: history.canRedo
            ),
            persistence: persistenceState
        )
    }

    private func sendDocumentEvent(kind: ProjectSessionDocumentChangeKind) {
        documentChangeSink.send(ProjectSessionDocumentChangeEvent(
            kind: kind,
            projectID: project?.id,
            generation: generation
        ))
    }
}
