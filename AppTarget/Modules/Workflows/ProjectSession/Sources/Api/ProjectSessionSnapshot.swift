import Foundation
import Project

public struct ProjectSessionHistoryState: Equatable, Sendable {
    public let canUndo: Bool
    public let canRedo: Bool

    public init(canUndo: Bool, canRedo: Bool) {
        self.canUndo = canUndo
        self.canRedo = canRedo
    }

    public static let empty = ProjectSessionHistoryState(canUndo: false, canRedo: false)
}

public enum ProjectSessionSaveKind: Equatable, Sendable {
    case autosave
    case explicit
}

public enum ProjectSessionPersistenceFailureReason: Equatable, Sendable {
    case repositoryRejectedSave
}

public struct ProjectSessionPersistenceFailure: Error, Equatable, Sendable {
    public let projectID: UUID
    public let saveKind: ProjectSessionSaveKind
    public let reason: ProjectSessionPersistenceFailureReason

    public init(
        projectID: UUID,
        saveKind: ProjectSessionSaveKind,
        reason: ProjectSessionPersistenceFailureReason
    ) {
        self.projectID = projectID
        self.saveKind = saveKind
        self.reason = reason
    }
}

public enum ProjectSessionPersistenceState: Equatable, Sendable {
    case idle
    case saving(ProjectSessionSaveKind)
    case saved(ProjectSessionSaveKind)
    case failed(ProjectSessionPersistenceFailure)
}

public struct ProjectSessionSnapshot: Equatable {
    public let project: Project?
    public let history: ProjectSessionHistoryState
    public let persistence: ProjectSessionPersistenceState
    public let interaction: ProjectSessionInteractionState
    public let effects: ProjectSessionEffectsState

    public init(
        project: Project?,
        history: ProjectSessionHistoryState,
        persistence: ProjectSessionPersistenceState,
        interaction: ProjectSessionInteractionState = .empty,
        effects: ProjectSessionEffectsState = .empty
    ) {
        self.project = project
        self.history = history
        self.persistence = persistence
        self.interaction = interaction
        self.effects = effects
    }
}

public enum ProjectSessionDocumentChangeKind: Equatable, Sendable {
    case opened
    case changed
    case undo
    case redo
    case closed
}

public struct ProjectSessionDocumentChangeEvent: Equatable, Sendable {
    public let kind: ProjectSessionDocumentChangeKind
    public let projectID: UUID?
    public let generation: UInt

    public init(kind: ProjectSessionDocumentChangeKind, projectID: UUID?, generation: UInt) {
        self.kind = kind
        self.projectID = projectID
        self.generation = generation
    }
}
