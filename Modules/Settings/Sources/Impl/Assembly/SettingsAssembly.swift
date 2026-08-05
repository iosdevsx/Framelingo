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

    public static func loadSettings(
        userDefaults: UserDefaults = .standard,
        key: String = defaultStorageKey
    ) -> AppSettings {
        guard let data = userDefaults.data(forKey: key),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return .default
        }

        return settings
    }

    public static func saveSettings(
        _ settings: AppSettings,
        userDefaults: UserDefaults = .standard,
        key: String = defaultStorageKey
    ) {
        guard let data = try? JSONEncoder().encode(settings) else {
            return
        }

        userDefaults.set(data, forKey: key)
    }
}
