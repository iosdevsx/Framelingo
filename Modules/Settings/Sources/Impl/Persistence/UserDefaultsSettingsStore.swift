import Foundation
import Settings

final class UserDefaultsSettingsStore: SettingsStore {
    private let userDefaults: UserDefaults
    private let key: String

    init(userDefaults: UserDefaults, key: String) {
        self.userDefaults = userDefaults
        self.key = key
    }

    func load() async throws -> AppSettings {
        guard let data = userDefaults.data(forKey: key),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return .default
        }

        return settings
    }

    func save(_ settings: AppSettings) async throws {
        guard let data = try? JSONEncoder().encode(settings) else {
            return
        }

        userDefaults.set(data, forKey: key)
    }
}
