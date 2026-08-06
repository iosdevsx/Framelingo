import Foundation

public enum SubtitleTextMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case original
    case translated
    case translatedFallbackToOriginal

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .original:
            return "Original"
        case .translated:
            return "Translated"
        case .translatedFallbackToOriginal:
            return "Translated fallback to original"
        }
    }
}
