public protocol SubtitleParsing {
    func parseSRT(_ content: String) throws -> [SubtitleSegment]
}
