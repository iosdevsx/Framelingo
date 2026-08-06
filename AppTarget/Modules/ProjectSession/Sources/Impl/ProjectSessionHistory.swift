import Project
import ProjectSession

struct ProjectSessionHistory {
    struct DocumentState {
        let project: Project
        let interaction: ProjectSessionInteractionState
    }

    struct Interaction {
        let name: String
        let initialState: DocumentState
        var changed = false
    }

    private let limit: Int
    private(set) var undoStates: [DocumentState] = []
    private(set) var redoStates: [DocumentState] = []
    private(set) var interaction: Interaction?

    init(limit: Int) {
        self.limit = max(limit, 0)
    }

    var canUndo: Bool { !undoStates.isEmpty }
    var canRedo: Bool { !redoStates.isEmpty }

    mutating func record(previous: DocumentState) {
        if interaction != nil {
            interaction?.changed = true
            redoStates.removeAll()
            return
        }

        appendUndo(previous)
        redoStates.removeAll()
    }

    mutating func beginInteraction(named name: String, state: DocumentState) {
        guard interaction == nil else { return }
        interaction = Interaction(name: name, initialState: state)
    }

    mutating func endInteraction(named name: String, currentState: DocumentState) -> Bool {
        guard let interaction, interaction.name == name else { return false }
        self.interaction = nil

        guard interaction.changed,
              !projectsMatchIgnoringUpdateDate(
                interaction.initialState.project,
                currentState.project
              ) else {
            return false
        }

        appendUndo(interaction.initialState)
        redoStates.removeAll()
        return true
    }

    mutating func undo(current: DocumentState) -> DocumentState? {
        guard let previous = undoStates.popLast() else { return nil }
        redoStates.append(current)
        return previous
    }

    mutating func redo(current: DocumentState) -> DocumentState? {
        guard let next = redoStates.popLast() else { return nil }
        appendUndo(current)
        return next
    }

    mutating func reset() {
        undoStates.removeAll()
        redoStates.removeAll()
        interaction = nil
    }

    mutating func discardInteraction() {
        interaction = nil
    }

    private mutating func appendUndo(_ state: DocumentState) {
        guard limit > 0 else { return }
        undoStates.append(state)
        if undoStates.count > limit {
            undoStates.removeFirst(undoStates.count - limit)
        }
    }

    private func projectsMatchIgnoringUpdateDate(_ lhs: Project, _ rhs: Project) -> Bool {
        var normalized = rhs
        normalized.updatedAt = lhs.updatedAt
        return lhs == normalized
    }
}
