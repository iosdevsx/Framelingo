import Foundation

enum AppError: LocalizedError {
    case unsupportedFileFormat
    case projectSaveFailed
    case videoFileMissing(String)
    case invalidSubtitleTimestamp
    case ffmpegNotFound
    case transcriptionFailed
    case translationFailed
    case exportFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedFileFormat:
            "Unsupported file format."
        case .projectSaveFailed:
            "Project save failed."
        case .videoFileMissing(let path):
            "Video file is missing at path: \(path)"
        case .invalidSubtitleTimestamp:
            "Subtitle timestamp is invalid."
        case .ffmpegNotFound:
            "FFmpeg is not installed or the configured path is invalid."
        case .transcriptionFailed:
            "Transcription failed."
        case .translationFailed:
            "Translation failed."
        case .exportFailed:
            "Export failed."
        }
    }
}
