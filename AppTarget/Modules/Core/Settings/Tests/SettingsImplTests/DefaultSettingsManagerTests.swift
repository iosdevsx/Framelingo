import Combine
import Foundation
import Settings
import Testing
@testable import SettingsImpl

@MainActor
struct DefaultSettingsManagerTests {
    @Test
    func publishesCommittedSettingsAndSuccessfulPersistence() async {
        let store = RecordingSettingsStore()
        let manager = makeManager(store: store)
        var snapshots: [SettingsSnapshot] = []
        let subscription = manager.snapshots.sink { snapshots.append($0) }
        var updated = AppSettings.default
        updated.ffmpegPath = "/custom/ffmpeg"

        manager.update(updated)
        await manager.waitForPendingPersistence()

        #expect(manager.snapshot.settings == updated)
        #expect(manager.snapshot.persistenceState == .saved)
        #expect(await store.savedSettings == [updated])
        #expect(snapshots.map(\.persistenceState) == [.idle, .saving, .saved])
        withExtendedLifetime(subscription) {}
    }

    @Test
    func rapidUpdatesPersistOnlyInOrderAndFinishWithLatestValue() async {
        let store = RecordingSettingsStore(saveDelay: .milliseconds(30))
        let manager = makeManager(store: store)
        var first = AppSettings.default
        first.ffmpegPath = "/older"
        var latest = first
        latest.ffmpegPath = "/latest"

        manager.update(first)
        await waitUntil { await store.saveStartedCount == 1 }
        manager.update(latest)
        await manager.waitForPendingPersistence()

        #expect(await store.savedSettings == [first, latest])
        #expect(manager.snapshot.settings == latest)
        #expect(manager.snapshot.persistenceState == .saved)
    }

    @Test
    func saveFailureIsObservableAndKeepsCommittedInMemoryValue() async {
        let store = RecordingSettingsStore(saveFailure: .save)
        let manager = makeManager(store: store)
        var updated = AppSettings.default
        updated.translationProviderName = "Offline"

        manager.update(updated)
        await manager.waitForPendingPersistence()

        #expect(manager.snapshot.settings == updated)
        guard case .failed(let failure) = manager.snapshot.persistenceState else {
            Issue.record("Expected failed persistence state")
            return
        }
        #expect(failure.operation == .save)
        #expect(failure.message == TestStoreFailure.save.errorDescription)
    }

    @Test
    func failedReloadKeepsCurrentValueAndPublishesLoadFailure() async {
        var initial = AppSettings.default
        initial.subtitleFontSize = 22
        let store = RecordingSettingsStore(loadFailure: .load)
        let manager = makeManager(store: store, initial: initial)

        await manager.reload()

        #expect(manager.snapshot.settings == initial)
        guard case .failed(let failure) = manager.snapshot.persistenceState else {
            Issue.record("Expected failed persistence state")
            return
        }
        #expect(failure.operation == .load)
        #expect(failure.message == TestStoreFailure.load.errorDescription)
    }

    private func makeManager(
        store: any SettingsStore,
        initial: AppSettings = .default
    ) -> DefaultSettingsManager {
        DefaultSettingsManager(
            store: store,
            initialSnapshot: SettingsSnapshot(
                settings: initial,
                persistenceState: .idle
            )
        )
    }

    private func waitUntil(
        _ predicate: () async -> Bool
    ) async {
        for _ in 0..<100 {
            if await predicate() {
                return
            }
            do {
                try await Task.sleep(for: .milliseconds(1))
            } catch {
                Issue.record("Waiting for asynchronous state was cancelled")
                return
            }
        }
        Issue.record("Timed out waiting for asynchronous state")
    }
}

private enum TestStoreFailure: Error, LocalizedError {
    case load
    case save

    var errorDescription: String? {
        switch self {
        case .load: "Test settings load failed."
        case .save: "Test settings save failed."
        }
    }
}

private actor RecordingSettingsStore: SettingsStore {
    private let loadedSettings: AppSettings
    private let loadFailure: TestStoreFailure?
    private let saveFailure: TestStoreFailure?
    private let saveDelay: Duration
    private(set) var savedSettings: [AppSettings] = []
    private(set) var saveStartedCount = 0

    init(
        loadedSettings: AppSettings = .default,
        loadFailure: TestStoreFailure? = nil,
        saveFailure: TestStoreFailure? = nil,
        saveDelay: Duration = .zero
    ) {
        self.loadedSettings = loadedSettings
        self.loadFailure = loadFailure
        self.saveFailure = saveFailure
        self.saveDelay = saveDelay
    }

    func load() async throws -> AppSettings {
        if let loadFailure {
            throw loadFailure
        }
        return loadedSettings
    }

    func save(_ settings: AppSettings) async throws {
        saveStartedCount += 1
        if saveDelay > .zero {
            try await Task.sleep(for: saveDelay)
        }
        if let saveFailure {
            throw saveFailure
        }
        savedSettings.append(settings)
    }
}
