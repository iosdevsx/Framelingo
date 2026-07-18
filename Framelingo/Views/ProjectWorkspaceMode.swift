import Foundation

enum ProjectWorkspaceMode: String, CaseIterable, Identifiable {
    case subtitles
    case edit
    case shorts

    var id: String { rawValue }

    var title: String {
        switch self {
        case .subtitles:
            return "Subtitles"
        case .edit:
            return "Edit"
        case .shorts:
            return "Shorts"
        }
    }
}
