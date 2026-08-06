import Foundation

public enum VideoExportPreset: String, Codable, CaseIterable, Identifiable, Sendable {
    case fast
    case medium
    case slow

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .fast: "Fast"
        case .medium: "Medium"
        case .slow: "Slow"
        }
    }
}
