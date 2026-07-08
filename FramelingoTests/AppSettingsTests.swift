import XCTest
@testable import Framelingo

final class AppSettingsTests: XCTestCase {
    func testDecodingPayloadWithoutVADKeysUsesDefaults() throws {
        let legacyJSON = """
        {
            "speechToTextProviderName": "Local Whisper",
            "translationProviderName": "Mock Translation",
            "ffmpegPath": "/opt/homebrew/bin/ffmpeg",
            "whisperExecutablePath": "/usr/local/bin/whisper-cli",
            "whisperModelName": "small",
            "whisperModelPath": "/models/ggml-small.bin",
            "defaultExportFormat": "srt",
            "subtitleFontSize": 16,
            "subtitleBackgroundOpacity": 0.65,
            "subtitleMaxLines": 3
        }
        """

        let settings = try JSONDecoder().decode(AppSettings.self, from: Data(legacyJSON.utf8))

        XCTAssertEqual(settings.whisperVADModelPath, "")
        XCTAssertTrue(settings.whisperVADEnabled)
        XCTAssertEqual(settings.whisperModelName, "small")
        XCTAssertEqual(settings.whisperModelPath, "/models/ggml-small.bin")
    }

    func testVADFieldsRoundtrip() throws {
        var settings = AppSettings.default
        settings.whisperVADModelPath = "/models/ggml-silero-v5.1.2.bin"
        settings.whisperVADEnabled = false

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)

        XCTAssertEqual(decoded.whisperVADModelPath, "/models/ggml-silero-v5.1.2.bin")
        XCTAssertFalse(decoded.whisperVADEnabled)
    }
}
