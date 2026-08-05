import Subtitles

public struct SubtitleTranslationResult: Equatable {
    public var segments: [SubtitleSegment]

    public init(segments: [SubtitleSegment]) {
        self.segments = segments
    }
}
