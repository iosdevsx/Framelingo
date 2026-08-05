import Foundation

public enum ProjectFileError: LocalizedError {
    case videoFileMissing(String)

    public var errorDescription: String? {
        switch self {
        case .videoFileMissing(let path):
            "Project opened, but the source video file was not found:\n\(path)"
        }
    }
}
