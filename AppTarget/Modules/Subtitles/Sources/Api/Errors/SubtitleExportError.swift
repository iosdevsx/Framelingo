import Foundation

public enum SubtitleExportError: LocalizedError {
    case emptySubtitles
    case exportFailed

    public var errorDescription: String? {
        switch self {
        case .emptySubtitles:
            "There are no subtitles to export."
        case .exportFailed:
            "Export failed."
        }
    }
}
