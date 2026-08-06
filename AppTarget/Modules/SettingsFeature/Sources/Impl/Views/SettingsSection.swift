import Foundation

enum SettingsSection: String, CaseIterable, Identifiable {
    case tools
    case appearance
    case shortcuts
    case about

    var id: String { rawValue }

    var label: String {
        switch self {
        case .tools: "Tools"
        case .appearance: "Appearance"
        case .shortcuts: "Shortcuts"
        case .about: "About"
        }
    }

    var icon: String {
        switch self {
        case .tools: "gearshape"
        case .appearance: "paintbrush"
        case .shortcuts: "keyboard"
        case .about: "film"
        }
    }
}
