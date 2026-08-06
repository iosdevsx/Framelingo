public enum ProjectWorkspaceMode: String, CaseIterable, Identifiable {
    case subtitles
    case edit
    case shorts

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .subtitles: "Subtitles"
        case .edit: "Edit"
        case .shorts: "Shorts"
        }
    }
}
