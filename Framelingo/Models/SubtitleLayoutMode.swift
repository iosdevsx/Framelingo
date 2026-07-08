import SwiftUI

enum SubtitleLayoutMode: String, CaseIterable, Identifiable {
    case split
    case videoFocus
    case transcript

    var id: String { rawValue }
}

enum EditorDensity: String, CaseIterable, Identifiable {
    case compact
    case comfy

    var id: String { rawValue }
}

enum AccentColorName: String, CaseIterable, Identifiable {
    case blue
    case purple
    case green
    case orange
    case pink

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }

    var color: Color {
        switch self {
        case .blue:   return Color(hex: "#0a84ff") ?? .blue
        case .purple: return Color(hex: "#bf5af2") ?? .purple
        case .green:  return Color(hex: "#30d158") ?? .green
        case .orange: return Color(hex: "#ff9f0a") ?? .orange
        case .pink:   return Color(hex: "#ff375f") ?? .pink
        }
    }
}
