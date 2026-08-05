public enum SubtitleImportMode: String, CaseIterable, Identifiable {
    case replaceExisting
    case appendToExisting

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .replaceExisting:
            "Replace existing subtitles"
        case .appendToExisting:
            "Append to existing subtitles"
        }
    }
}
