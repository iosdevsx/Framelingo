import Foundation

public enum SubtitleEditorFocus: Hashable {
    case start(UUID)
    case end(UUID)
    case original(UUID)
    case translation(UUID)

    public var textEditSegmentID: UUID? {
        switch self {
        case .original(let id), .translation(let id):
            id
        case .start, .end:
            nil
        }
    }

    public var translationSegmentID: UUID? {
        switch self {
        case .translation(let id):
            id
        case .start, .end, .original:
            nil
        }
    }

    public var timingSegmentID: UUID? {
        switch self {
        case .start(let id), .end(let id):
            id
        case .original, .translation:
            nil
        }
    }
}
