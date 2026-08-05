import Foundation

public enum SubtitlePosition: String, Codable, CaseIterable, Identifiable, Sendable {
    case bottom
    case center
    case top

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .bottom: "Bottom"
        case .center: "Center"
        case .top: "Top"
        }
    }

    public var defaultYOffset: Double {
        switch self {
        case .bottom: 0.86
        case .center: 0.5
        case .top: 0.14
        }
    }
}
