import Foundation

public enum EditTimelineError: LocalizedError, Equatable {
    case invalidDuration
    case invalidRange
    case cannotDeleteEntireTimeline
    case clipNotFound
    case splitOutsideTimeline

    public var errorDescription: String? {
        switch self {
        case .invalidDuration:
            return "Video duration is unknown. Open the video first."
        case .invalidRange:
            return "Select a range of at least 500 ms."
        case .cannotDeleteEntireTimeline:
            return "Cannot delete the entire timeline."
        case .clipNotFound:
            return "Selected clip was not found."
        case .splitOutsideTimeline:
            return "Playhead is outside the editable timeline."
        }
    }
}
