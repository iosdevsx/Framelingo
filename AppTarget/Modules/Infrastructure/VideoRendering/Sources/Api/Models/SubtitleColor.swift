import Foundation

public enum SubtitleColor: String, Codable, CaseIterable, Identifiable, Sendable {
    case white
    case yellow

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .white: "White"
        case .yellow: "Yellow"
        }
    }
}
