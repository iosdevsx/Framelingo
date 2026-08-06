import Subtitles

struct StubSubtitleParser: SubtitleParsing {
    func parseSRT(_ content: String) throws -> [SubtitleSegment] {
        []
    }
}
