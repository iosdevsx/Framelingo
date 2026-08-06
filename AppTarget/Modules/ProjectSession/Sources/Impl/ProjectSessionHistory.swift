import Project

struct ProjectSessionHistory {
    struct Interaction {
        let name: String
        let initialProject: Project
        var changed = false
    }

    private let limit: Int
    private(set) var undoProjects: [Project] = []
    private(set) var redoProjects: [Project] = []
    private(set) var interaction: Interaction?

    init(limit: Int) {
        self.limit = max(limit, 0)
    }

    var canUndo: Bool { !undoProjects.isEmpty }
    var canRedo: Bool { !redoProjects.isEmpty }

    mutating func record(previous: Project) {
        if interaction != nil {
            interaction?.changed = true
            redoProjects.removeAll()
            return
        }

        appendUndo(previous)
        redoProjects.removeAll()
    }

    mutating func beginInteraction(named name: String, project: Project) {
        guard interaction == nil else { return }
        interaction = Interaction(name: name, initialProject: project)
    }

    mutating func endInteraction(named name: String, currentProject: Project) -> Bool {
        guard let interaction, interaction.name == name else { return false }
        self.interaction = nil

        guard interaction.changed,
              !projectsMatchIgnoringUpdateDate(interaction.initialProject, currentProject) else {
            return false
        }

        appendUndo(interaction.initialProject)
        redoProjects.removeAll()
        return true
    }

    mutating func undo(current: Project) -> Project? {
        guard let previous = undoProjects.popLast() else { return nil }
        redoProjects.append(current)
        return previous
    }

    mutating func redo(current: Project) -> Project? {
        guard let next = redoProjects.popLast() else { return nil }
        appendUndo(current)
        return next
    }

    mutating func reset() {
        undoProjects.removeAll()
        redoProjects.removeAll()
        interaction = nil
    }

    mutating func discardInteraction() {
        interaction = nil
    }

    private mutating func appendUndo(_ project: Project) {
        guard limit > 0 else { return }
        undoProjects.append(project)
        if undoProjects.count > limit {
            undoProjects.removeFirst(undoProjects.count - limit)
        }
    }

    private func projectsMatchIgnoringUpdateDate(_ lhs: Project, _ rhs: Project) -> Bool {
        var normalized = rhs
        normalized.updatedAt = lhs.updatedAt
        return lhs == normalized
    }
}
