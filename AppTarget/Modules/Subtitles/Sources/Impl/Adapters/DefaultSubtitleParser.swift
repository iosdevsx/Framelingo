import Subtitles

struct DefaultSubtitleParser: SubtitleParsing {
    func parseSRT(_ content: String) throws -> [SubtitleSegment] {
        try SRTSubtitleParser().parse(content).segments
    }
}
