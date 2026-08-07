import Combine
import Foundation

public enum SettingsPersistenceOperation: String, Equatable {
    case load
    case save
}

public struct SettingsPersistenceFailure: Error, Equatable, LocalizedError {
    public let operation: SettingsPersistenceOperation
    public let message: String

    public init(operation: SettingsPersistenceOperation, message: String) {
        self.operation = operation
        self.message = message
    }

    public var errorDescription: String? {
        message
    }
}

public enum SettingsPersistenceState: Equatable {
    case idle
    case saving
    case saved
    case failed(SettingsPersistenceFailure)
}

/// Immutable value published by the settings owner. Consumers edit a local
/// copy and submit it through `SettingsAccess.update(_:)`.
public struct SettingsSnapshot: Equatable {
    public let settings: AppSettings
    public let persistenceState: SettingsPersistenceState

    public init(
        settings: AppSettings,
        persistenceState: SettingsPersistenceState
    ) {
        self.settings = settings
        self.persistenceState = persistenceState
    }
}

@MainActor
public protocol SettingsManaging: AnyObject {
    var snapshot: SettingsSnapshot { get }
    var snapshots: AnyPublisher<SettingsSnapshot, Never> { get }

    func reload() async
    func update(_ settings: AppSettings)
}

/// API-owned closure facade used by features and their tests. It prevents
/// feature targets from importing or naming the concrete SettingsImpl owner.
@MainActor
public struct SettingsAccess {
    private let snapshotProvider: @MainActor () -> SettingsSnapshot
    private let snapshotsProvider: @MainActor () -> AnyPublisher<SettingsSnapshot, Never>
    private let reloadAction: @MainActor () async -> Void
    private let updateAction: @MainActor (AppSettings) -> Void

    public init(
        snapshot: @escaping @MainActor () -> SettingsSnapshot,
        snapshots: @escaping @MainActor () -> AnyPublisher<SettingsSnapshot, Never>,
        reload: @escaping @MainActor () async -> Void,
        update: @escaping @MainActor (AppSettings) -> Void
    ) {
        snapshotProvider = snapshot
        snapshotsProvider = snapshots
        reloadAction = reload
        updateAction = update
    }

    public var snapshot: SettingsSnapshot {
        snapshotProvider()
    }

    public var snapshots: AnyPublisher<SettingsSnapshot, Never> {
        snapshotsProvider()
    }

    public func reload() async {
        await reloadAction()
    }

    public func update(_ settings: AppSettings) {
        updateAction(settings)
    }
}

public extension SettingsManaging {
    var access: SettingsAccess {
        SettingsAccess(
            snapshot: { self.snapshot },
            snapshots: { self.snapshots },
            reload: { await self.reload() },
            update: { self.update($0) }
        )
    }
}
