import Combine
import Foundation
import Settings

@MainActor
final class DefaultSettingsManager: SettingsManaging {
    private(set) var snapshot: SettingsSnapshot
    var snapshots: AnyPublisher<SettingsSnapshot, Never> {
        subject.eraseToAnyPublisher()
    }

    private let store: any SettingsStore
    private let subject: CurrentValueSubject<SettingsSnapshot, Never>
    private var pendingSettings: AppSettings?
    private var persistenceTask: Task<Void, Never>?

    init(
        store: any SettingsStore,
        initialSnapshot: SettingsSnapshot
    ) {
        self.store = store
        snapshot = initialSnapshot
        subject = CurrentValueSubject(initialSnapshot)
    }

    deinit {
        persistenceTask?.cancel()
    }

    func reload() async {
        await waitForPendingPersistence()

        do {
            let settings = try await store.load()
            publish(SettingsSnapshot(settings: settings, persistenceState: .idle))
        } catch {
            publish(SettingsSnapshot(
                settings: snapshot.settings,
                persistenceState: .failed(Self.failure(for: error, operation: .load))
            ))
        }
    }

    func update(_ settings: AppSettings) {
        pendingSettings = settings
        publish(SettingsSnapshot(settings: settings, persistenceState: .saving))

        guard persistenceTask == nil else {
            return
        }

        persistenceTask = Task { [weak self] in
            await self?.drainPendingSaves()
        }
    }

    func waitForPendingPersistence() async {
        let task = persistenceTask
        await task?.value
    }

    private func drainPendingSaves() async {
        while let settings = pendingSettings {
            pendingSettings = nil

            do {
                try Task.checkCancellation()
                try await store.save(settings)
                if pendingSettings == nil {
                    publish(SettingsSnapshot(
                        settings: snapshot.settings,
                        persistenceState: .saved
                    ))
                }
            } catch is CancellationError {
                persistenceTask = nil
                return
            } catch {
                publish(SettingsSnapshot(
                    settings: snapshot.settings,
                    persistenceState: .failed(Self.failure(for: error, operation: .save))
                ))
                if pendingSettings != nil {
                    publish(SettingsSnapshot(
                        settings: snapshot.settings,
                        persistenceState: .saving
                    ))
                }
            }
        }

        persistenceTask = nil
    }

    private func publish(_ snapshot: SettingsSnapshot) {
        self.snapshot = snapshot
        subject.send(snapshot)
    }

    private static func failure(
        for error: Error,
        operation: SettingsPersistenceOperation
    ) -> SettingsPersistenceFailure {
        let fallback = operation == .load
            ? "Settings could not be loaded. Defaults remain active."
            : "Settings could not be saved. The current value remains active for this session."
        let message = (error as? LocalizedError)?.errorDescription ?? fallback
        return SettingsPersistenceFailure(operation: operation, message: message)
    }
}
