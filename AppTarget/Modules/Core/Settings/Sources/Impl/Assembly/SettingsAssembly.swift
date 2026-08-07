import Foundation
import Settings

public enum SettingsAssembly {
    public static let defaultStorageKey = "Framelingo.AppSettings"

    public static func makeStore(
        userDefaults: UserDefaults = .standard,
        key: String = defaultStorageKey
    ) -> any SettingsStore {
        UserDefaultsSettingsStore(userDefaults: userDefaults, key: key)
    }

    @MainActor
    public static func makeManager(
        userDefaults: UserDefaults = .standard,
        key: String = defaultStorageKey
    ) -> any SettingsManaging {
        let store = UserDefaultsSettingsStore(userDefaults: userDefaults, key: key)
        let initialSnapshot: SettingsSnapshot
        do {
            initialSnapshot = SettingsSnapshot(
                settings: try store.loadSynchronously(),
                persistenceState: .idle
            )
        } catch {
            initialSnapshot = SettingsSnapshot(
                settings: .default,
                persistenceState: .failed(SettingsPersistenceFailure(
                    operation: .load,
                    message: "Settings could not be loaded. Defaults remain active."
                ))
            )
        }

        return DefaultSettingsManager(store: store, initialSnapshot: initialSnapshot)
    }

    @MainActor
    public static func makeManager(
        store: any SettingsStore,
        initialSettings: AppSettings = .default
    ) -> any SettingsManaging {
        DefaultSettingsManager(
            store: store,
            initialSnapshot: SettingsSnapshot(
                settings: initialSettings,
                persistenceState: .idle
            )
        )
    }
}
