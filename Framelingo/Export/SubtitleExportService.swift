import Foundation

enum SubtitleExportError: LocalizedError {
    case emptySubtitles

    var errorDescription: String? {
        switch self {
        case .emptySubtitles:
            "There are no subtitles to export."
        }
    }
}

enum SubtitleExportKind: CaseIterable, Identifiable {
    case translatedSRT
    case originalSRT
    case translatedVTT
    case originalVTT
    case txt

    var id: String { title }

    var title: String {
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

    var fileExtension: String {
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

protocol SubtitleExportService {
    func export(project: Project, kind: SubtitleExportKind, destinationURL: URL) async throws
}
