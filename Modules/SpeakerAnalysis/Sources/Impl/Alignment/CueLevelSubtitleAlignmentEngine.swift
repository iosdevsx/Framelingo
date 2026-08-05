import Foundation
import SpeakerAnalysis

struct CueLevelSubtitleAlignmentEngine: SubtitleAlignmentEngine {
    init() {
    }

    func align(
        words: [WordTiming],
        existingCues: [SubtitleAlignmentCue],
        speakerSegments: [SpeakerSegment],
        options: SubtitleAlignmentOptions
    ) async throws -> [SubtitleAlignmentCue] {
        try await align(
            existingCues: existingCues,
            speakerSegments: speakerSegments,
            options: options
        )
    }

    func align(
        existingCues: [SubtitleAlignmentCue],
        speakerSegments: [SpeakerSegment],
        options: SubtitleAlignmentOptions
    ) async throws -> [SubtitleAlignmentCue] {
        existingCues.enumerated().map { offset, cue in
            alignedCue(cue, index: offset + 1, speakerSegments: speakerSegments, options: options)
        }
    }

    private func alignedCue(
        _ cue: SubtitleAlignmentCue,
        index: Int,
        speakerSegments: [SpeakerSegment],
        options: SubtitleAlignmentOptions
    ) -> SubtitleAlignmentCue {
        let cueStart = SubtitleAlignmentMath.seconds(fromMilliseconds: cue.startMs)
        let cueEnd = SubtitleAlignmentMath.seconds(fromMilliseconds: cue.endMs)
        let overlaps = speakerSegments.compactMap { segment -> (segment: SpeakerSegment, duration: TimeInterval)? in
            let duration = SubtitleAlignmentMath.overlapDuration(startA: cueStart, endA: cueEnd, startB: segment.start, endB: segment.end)
            return duration > 0 ? (segment, duration) : nil
        }

        var alignedCue = cue
        alignedCue.index = index
        alignedCue.warnings = SubtitleAlignmentMath.durationWarnings(start: cueStart, end: cueEnd, options: options)

        guard let best = overlaps.max(by: { $0.duration < $1.duration }) else {
            alignedCue.speakerId = nil
            alignedCue.warnings.appendUnique(.noSpeakerDetected)
            return alignedCue
        }

        alignedCue.speakerId = best.segment.speakerId
        if overlaps.count > 1 {
            alignedCue.warnings.appendUnique(.overlappingSpeakers)
        }
        if let confidence = best.segment.confidence, confidence < options.lowConfidenceThreshold {
            alignedCue.warnings.appendUnique(.lowConfidenceSpeaker)
        }

        return alignedCue
    }
}
