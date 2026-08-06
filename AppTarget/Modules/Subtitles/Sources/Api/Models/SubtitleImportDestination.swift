public enum SubtitleImportDestination: String, CaseIterable, Identifiable {
    case original
    case translated

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .original:
            "Original text"
        case .translated:
            "Translated text"
        }
    }

    public var description: String {
        switch self {
        case .original:
            "Imported subtitle text will be stored as source/original text."
        case .translated:
            "Imported subtitle text will be stored as translated text."
        }
    }
}
