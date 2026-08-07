import SpeakerAnalysis

struct PassthroughSubtitleAlignmentEngine: SubtitleAlignmentEngine {
    init() {
    }

    func align(
        words: [WordTiming],
        existingCues: [SubtitleAlignmentCue],
        speakerSegments: [SpeakerSegment],
        options: SubtitleAlignmentOptions
    ) async throws -> [SubtitleAlignmentCue] {
        existingCues
    }

    func align(
        existingCues: [SubtitleAlignmentCue],
        speakerSegments: [SpeakerSegment],
        options: SubtitleAlignmentOptions
    ) async throws -> [SubtitleAlignmentCue] {
        existingCues
    }
}
