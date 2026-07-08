import Foundation

struct AppSettings: Codable, Equatable {
    var speechToTextProviderName: String
    var translationProviderName: String
    var ffmpegPath: String
    var whisperExecutablePath: String
    var whisperModelName: String
    var whisperModelPath: String
    var whisperVADModelPath: String
    var whisperVADEnabled: Bool
    var defaultExportFormat: ExportFormat
    var subtitleFontSize: Double
    var subtitleBackgroundOpacity: Double
    var subtitleMaxLines: Int

    static let `default` = AppSettings(
        speechToTextProviderName: "Mock Speech-to-Text",
        translationProviderName: "Mock Translation",
        ffmpegPath: "/opt/homebrew/bin/ffmpeg",
        whisperExecutablePath: "",
        whisperModelName: WhisperModel.base.rawValue,
        whisperModelPath: "",
        whisperVADModelPath: "",
        whisperVADEnabled: true,
        defaultExportFormat: .srt,
        subtitleFontSize: 16,
        subtitleBackgroundOpacity: 0.65,
        subtitleMaxLines: 3
    )

    enum CodingKeys: String, CodingKey {
        case speechToTextProviderName
        case translationProviderName
        case ffmpegPath
        case whisperExecutablePath
        case whisperModelName
        case whisperModelPath
        case whisperVADModelPath
        case whisperVADEnabled
        case defaultExportFormat
        case subtitleFontSize
        case subtitleBackgroundOpacity
        case subtitleMaxLines
    }

    init(
        speechToTextProviderName: String,
        translationProviderName: String,
        ffmpegPath: String,
        whisperExecutablePath: String,
        whisperModelName: String,
        whisperModelPath: String,
        whisperVADModelPath: String,
        whisperVADEnabled: Bool,
        defaultExportFormat: ExportFormat,
        subtitleFontSize: Double,
        subtitleBackgroundOpacity: Double,
        subtitleMaxLines: Int
    ) {
        self.speechToTextProviderName = speechToTextProviderName
        self.translationProviderName = translationProviderName
        self.ffmpegPath = ffmpegPath
        self.whisperExecutablePath = whisperExecutablePath
        self.whisperModelName = whisperModelName
        self.whisperModelPath = whisperModelPath
        self.whisperVADModelPath = whisperVADModelPath
        self.whisperVADEnabled = whisperVADEnabled
        self.defaultExportFormat = defaultExportFormat
        self.subtitleFontSize = subtitleFontSize
        self.subtitleBackgroundOpacity = subtitleBackgroundOpacity
        self.subtitleMaxLines = subtitleMaxLines
    }

    init(from decoder: Decoder) throws {
        let defaults = AppSettings.default
        let container = try decoder.container(keyedBy: CodingKeys.self)
        speechToTextProviderName = try container.decodeIfPresent(String.self, forKey: .speechToTextProviderName) ?? defaults.speechToTextProviderName
        translationProviderName = try container.decodeIfPresent(String.self, forKey: .translationProviderName) ?? defaults.translationProviderName
        ffmpegPath = try container.decodeIfPresent(String.self, forKey: .ffmpegPath) ?? defaults.ffmpegPath
        whisperExecutablePath = try container.decodeIfPresent(String.self, forKey: .whisperExecutablePath) ?? defaults.whisperExecutablePath
        whisperModelName = try container.decodeIfPresent(String.self, forKey: .whisperModelName) ?? defaults.whisperModelName
        whisperModelPath = try container.decodeIfPresent(String.self, forKey: .whisperModelPath) ?? defaults.whisperModelPath
        whisperVADModelPath = try container.decodeIfPresent(String.self, forKey: .whisperVADModelPath) ?? defaults.whisperVADModelPath
        whisperVADEnabled = try container.decodeIfPresent(Bool.self, forKey: .whisperVADEnabled) ?? defaults.whisperVADEnabled
        defaultExportFormat = try container.decodeIfPresent(ExportFormat.self, forKey: .defaultExportFormat) ?? defaults.defaultExportFormat
        subtitleFontSize = try container.decodeIfPresent(Double.self, forKey: .subtitleFontSize) ?? defaults.subtitleFontSize
        subtitleBackgroundOpacity = try container.decodeIfPresent(Double.self, forKey: .subtitleBackgroundOpacity) ?? defaults.subtitleBackgroundOpacity
        subtitleMaxLines = try container.decodeIfPresent(Int.self, forKey: .subtitleMaxLines) ?? defaults.subtitleMaxLines
    }
}
