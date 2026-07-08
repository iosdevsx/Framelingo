import Foundation

protocol SubtitleAlignmentEngine {
    func align(
        words: [WordTiming],
        existingCues: [SubtitleSegment],
        speakerSegments: [SpeakerSegment],
        options: SubtitleAlignmentOptions
    ) async throws -> [SubtitleSegment]

    func align(
        existingCues: [SubtitleSegment],
        speakerSegments: [SpeakerSegment],
        options: SubtitleAlignmentOptions
    ) async throws -> [SubtitleSegment]
}

extension SubtitleAlignmentEngine {
    func align(
        words: [WordTiming],
        existingCues: [SubtitleSegment],
        speakerSegments: [SpeakerSegment],
        options: SubtitleAlignmentOptions = SubtitleAlignmentOptions()
    ) async throws -> [SubtitleSegment] {
        try await align(
            words: words,
            existingCues: existingCues,
            speakerSegments: speakerSegments,
            options: options
        )
    }

    func align(
        existingCues: [SubtitleSegment],
        speakerSegments: [SpeakerSegment],
        options: SubtitleAlignmentOptions = SubtitleAlignmentOptions()
    ) async throws -> [SubtitleSegment] {
        try await align(
            existingCues: existingCues,
            speakerSegments: speakerSegments,
            options: options
        )
    }
}

struct PassthroughSubtitleAlignmentEngine: SubtitleAlignmentEngine {
    init() {
    }

    func align(
        words: [WordTiming],
        existingCues: [SubtitleSegment],
        speakerSegments: [SpeakerSegment],
        options: SubtitleAlignmentOptions
    ) async throws -> [SubtitleSegment] {
        existingCues
    }

    func align(
        existingCues: [SubtitleSegment],
        speakerSegments: [SpeakerSegment],
        options: SubtitleAlignmentOptions
    ) async throws -> [SubtitleSegment] {
        existingCues
    }
}
