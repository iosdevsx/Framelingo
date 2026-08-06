import SpeakerAnalysis
import Subtitles

public struct TranscriptionResult: Equatable {
    public var segments: [SubtitleSegment]
    public var words: [WordTiming]
    public var detectedLanguage: String?
    public var durationMs: Int?

    public init(
        segments: [SubtitleSegment],
        words: [WordTiming],
        detectedLanguage: String?,
        durationMs: Int?
    ) {
        self.segments = segments
        self.words = words
        self.detectedLanguage = detectedLanguage
        self.durationMs = durationMs
    }
}
