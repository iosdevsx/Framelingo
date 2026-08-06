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
        try loadSynchronously()
    }

    func loadSynchronously() throws -> AppSettings {
        guard let data = userDefaults.data(forKey: key) else {
            return .default
        }

        return try JSONDecoder().decode(AppSettings.self, from: data)
    }

    func save(_ settings: AppSettings) async throws {
        let data = try JSONEncoder().encode(settings)
        userDefaults.set(data, forKey: key)
    }
}
