public enum SubtitleExportKind: CaseIterable, Identifiable {
    case translatedSRT
    case originalSRT
    case translatedVTT
    case originalVTT
    case txt

    public var id: String { title }

    public var title: String {
        switch self {
        case .translatedSRT:
            "Export Translated SRT"
        case .originalSRT:
            "Export Original SRT"
        case .translatedVTT:
            "Export Translated VTT"
        case .originalVTT:
            "Export Original VTT"
        case .txt:
            "Export TXT"
        }
    }

    public var fileExtension: String {
        switch self {
        case .translatedSRT, .originalSRT:
            "srt"
        case .translatedVTT, .originalVTT:
            "vtt"
        case .txt:
            "txt"
        }
    }
}
