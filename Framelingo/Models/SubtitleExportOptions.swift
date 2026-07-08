import Foundation

enum SpeakerExportFormat: String, Codable, CaseIterable, Identifiable {
    case squareBrackets
    case webVTTVoiceTags
    case none

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .squareBrackets:
            "Square brackets"
        case .webVTTVoiceTags:
            "WebVTT voice tags"
        case .none:
            "None"
        }
    }
}

struct SubtitleExportOptions: Codable, Equatable {
    var includeSpeakerLabels: Bool
    var speakerFormat: SpeakerExportFormat

    init(
        includeSpeakerLabels: Bool = false,
        speakerFormat: SpeakerExportFormat = .squareBrackets
    ) {
        self.includeSpeakerLabels = includeSpeakerLabels
        self.speakerFormat = speakerFormat
    }
}
