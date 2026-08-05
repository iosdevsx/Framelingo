import Foundation

public enum SpeakerExportFormat: String, Codable, CaseIterable, Identifiable {
    case squareBrackets
    case webVTTVoiceTags
    case none

    public var id: String { rawValue }

    public var displayName: String {
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
