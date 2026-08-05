import Foundation

enum ApplicationExportError: LocalizedError, Equatable {
    case noSubtitles
    case mediaFileMissing
    case assGenerationFailed
    case editTimelineEmpty

    var errorDescription: String? {
        switch self {
        case .noSubtitles:
            return "There are no subtitles to export."
        case .mediaFileMissing:
            return "The original video file is missing."
        case .assGenerationFailed:
            return "Could not generate the subtitle file for export."
        case .editTimelineEmpty:
            return "The edit timeline has no clips to export. Review your cuts in Edit mode."
        }
    }
}
