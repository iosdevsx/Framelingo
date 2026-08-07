import Foundation

public enum SubtitleImportError: LocalizedError, Equatable {
    case unsupportedFormat(String)
    case fileReadFailed(String)
    case encodingDetectionFailed
    case emptyFile
    case parsingFailed(String)
    case noSegmentsFound
    case invalidTimecode(String)
    case userCancelled

    public var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let fileExtension):
            "Unsupported subtitle format: .\(fileExtension). Supported formats: srt, vtt, ass, ssa, txt, sbv."
        case .fileReadFailed(let message):
            "Could not read subtitle file. \(message)"
        case .encodingDetectionFailed:
            "Could not detect subtitle file encoding."
        case .emptyFile:
            "Subtitle file is empty."
        case .parsingFailed(let message):
            "Could not parse subtitle file. \(message)"
        case .noSegmentsFound:
            "No subtitle segments were found in this file."
        case .invalidTimecode(let value):
            "Invalid subtitle timecode: \(value)"
        case .userCancelled:
            "Subtitle import was cancelled."
        }
    }
}
