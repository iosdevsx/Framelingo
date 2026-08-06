import Combine
import Project

/// Narrow product-shell access for the project workspace. It intentionally
/// exposes no navigation, settings, catalog, or platform services.
@MainActor
public struct ProjectSelectionAccess {
    private let currentAction: () -> Project?
    private let updatesAction: () -> AnyPublisher<Project?, Never>
    private let updateAction: (Project) -> Void
    private let closeAction: () async -> Void

    public init(
        current: @escaping () -> Project?,
        updates: @escaping () -> AnyPublisher<Project?, Never>,
        update: @escaping (Project) -> Void,
        close: @escaping () async -> Void
    ) {
        currentAction = current
        updatesAction = updates
        updateAction = update
        closeAction = close
    }

    public var current: Project? {
        currentAction()
    }

    public var updates: AnyPublisher<Project?, Never> {
        updatesAction()
    }

    public func update(_ project: Project) {
        updateAction(project)
    }

    public func close() async {
        await closeAction()
    }
}
