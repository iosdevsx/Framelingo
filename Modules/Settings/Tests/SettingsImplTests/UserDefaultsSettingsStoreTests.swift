import Foundation
import Settings
import Testing
@testable import SettingsImpl

struct UserDefaultsSettingsStoreTests {
    @Test
    func legacyFixtureSurvivesCurrentUserDefaultsPayloadPath() async throws {
        let fixtureURL = try #require(Bundle.module.url(
            forResource: "LegacyAppSettings",
            withExtension: "json",
            subdirectory: "Fixtures"
        ))
        let data = try Data(contentsOf: fixtureURL)
        let suiteName = "Framelingo.SettingsImplTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(data, forKey: SettingsAssembly.defaultStorageKey)
        let store = SettingsAssembly.makeStore(userDefaults: defaults)
        let settings = try await store.load()

        #expect(settings.speechToTextProviderName == "Local Whisper")
        #expect(settings.whisperModelName == "small")
        #expect(settings.defaultExportFormat == .srt)
        #expect(settings.subtitleFontSize == 18)
        #expect(settings.subtitleBackgroundOpacity == 0.7)
    }

    @Test
    func currentSettingsRoundTripThroughStore() async throws {
        let suiteName = "Framelingo.SettingsImplTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = SettingsAssembly.makeStore(userDefaults: defaults)
        var expected = AppSettings.default
        expected.ffmpegPath = "/Applications/Tools/ffmpeg"
        expected.defaultExportFormat = .vtt

        try await store.save(expected)

        #expect(try await store.load() == expected)
    }
}
