import SwiftUI

public enum AccentColorName: String, CaseIterable, Identifiable {
    case blue
    case purple
    case green
    case orange
    case pink

    public var id: String { rawValue }

    public var displayName: String { rawValue.capitalized }

    public var color: Color {
        switch self {
        case .blue: Color(hex: "#0a84ff") ?? .blue
        case .purple: Color(hex: "#bf5af2") ?? .purple
        case .green: Color(hex: "#30d158") ?? .green
        case .orange: Color(hex: "#ff9f0a") ?? .orange
        case .pink: Color(hex: "#ff375f") ?? .pink
        }
    }
}
