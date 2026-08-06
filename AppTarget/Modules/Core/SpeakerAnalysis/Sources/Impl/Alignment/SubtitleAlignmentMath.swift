import Foundation
import SpeakerAnalysis

enum SubtitleAlignmentMath {
    static func seconds(fromMilliseconds milliseconds: Int) -> TimeInterval {
        TimeInterval(milliseconds) / 1_000
    }

    static func milliseconds(fromSeconds seconds: TimeInterval) -> Int {
        Int((seconds * 1_000).rounded())
    }

    static func overlapDuration(
        startA: TimeInterval,
        endA: TimeInterval,
        startB: TimeInterval,
        endB: TimeInterval
    ) -> TimeInterval {
        max(0, min(endA, endB) - max(startA, startB))
    }

    static func durationWarnings(
        start: TimeInterval,
        end: TimeInterval,
        options: SubtitleAlignmentOptions
    ) -> [SubtitleCueWarning] {
        let duration = max(0, end - start)
        var warnings: [SubtitleCueWarning] = []
        if duration > options.maxCueDuration {
            warnings.append(.tooLong)
        }
        if duration < options.minCueDuration {
            warnings.append(.tooShort)
        }
        return warnings
    }
}
