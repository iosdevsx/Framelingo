import Foundation

public enum MediaMetadataError: LocalizedError, Equatable {
    case videoTrackMissing
    case invalidVideoDimensions

    public var errorDescription: String? {
        switch self {
        case .videoTrackMissing:
            return "The video track could not be read."
        case .invalidVideoDimensions:
            return "The video dimensions are invalid."
        }
    }
}
