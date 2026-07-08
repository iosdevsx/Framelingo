import Foundation

enum SubtitleEditorFocus: Hashable {
    case start(UUID)
    case end(UUID)
    case original(UUID)
    case translation(UUID)

    var textEditSegmentID: UUID? {
        switch self {
        case .original(let id), .translation(let id):
            id
        case .start, .end:
            nil
        }
    }

    var translationSegmentID: UUID? {
        switch self {
        case .translation(let id):
            id
        case .start, .end, .original:
            nil
        }
    }

    var timingSegmentID: UUID? {
        switch self {
        case .start(let id), .end(let id):
            id
        case .original, .translation:
            nil
        }
    }
}
