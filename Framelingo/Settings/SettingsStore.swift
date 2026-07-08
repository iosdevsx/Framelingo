import Foundation

protocol SettingsStore {
    func load() async throws -> AppSettings
    func save(_ settings: AppSettings) async throws
}
