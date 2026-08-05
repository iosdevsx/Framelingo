public protocol SubtitleAlignmentEngine {
    func align(
        words: [WordTiming],
        existingCues: [SubtitleAlignmentCue],
        speakerSegments: [SpeakerSegment],
        options: SubtitleAlignmentOptions
    ) async throws -> [SubtitleAlignmentCue]

    func align(
        existingCues: [SubtitleAlignmentCue],
        speakerSegments: [SpeakerSegment],
        options: SubtitleAlignmentOptions
    ) async throws -> [SubtitleAlignmentCue]
}
