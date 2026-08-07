public extension SubtitleAlignmentEngine {
    func align(
        words: [WordTiming],
        existingCues: [SubtitleAlignmentCue],
        speakerSegments: [SpeakerSegment],
        options: SubtitleAlignmentOptions = SubtitleAlignmentOptions()
    ) async throws -> [SubtitleAlignmentCue] {
        try await align(
            words: words,
            existingCues: existingCues,
            speakerSegments: speakerSegments,
            options: options
        )
    }

    func align(
        existingCues: [SubtitleAlignmentCue],
        speakerSegments: [SpeakerSegment],
        options: SubtitleAlignmentOptions = SubtitleAlignmentOptions()
    ) async throws -> [SubtitleAlignmentCue] {
        try await align(
            existingCues: existingCues,
            speakerSegments: speakerSegments,
            options: options
        )
    }
}
