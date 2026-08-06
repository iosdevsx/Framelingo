import Combine
import Project

/// Narrow product-shell access for the project workspace. It intentionally
/// exposes no navigation, settings, catalog, or platform services.
@MainActor
public struct ProjectSelectionAccess {
    private let currentAction: () -> Project?
    private let updatesAction: () -> AnyPublisher<Project?, Never>
    private let closeAction: () async -> Void

    public init(
        current: @escaping () -> Project?,
        updates: @escaping () -> AnyPublisher<Project?, Never>,
        close: @escaping () async -> Void
    ) {
        currentAction = current
        updatesAction = updates
        closeAction = close
    }

    public var current: Project? {
        currentAction()
    }

    public var updates: AnyPublisher<Project?, Never> {
        updatesAction()
    }

    public func close() async {
        await closeAction()
    }
}
