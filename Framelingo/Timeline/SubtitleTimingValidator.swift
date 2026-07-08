import Foundation

enum SubtitleTimelineEditEdge {
    case left
    case right
}

enum SubtitleTimingValidator {
    static let minimumDurationMs = 500
    static let minimumGapMs = 50

    static func resizeSegment(
        segments: [SubtitleSegment],
        id: UUID,
        edge: SubtitleTimelineEditEdge,
        deltaMs: Int,
        durationMs: Int
    ) -> [SubtitleSegment] {
        let sortedSegments = sorted(segments)
        guard let index = sortedSegments.firstIndex(where: { $0.id == id }) else {
            return reindexed(sortedSegments)
        }

        var updatedSegments = sortedSegments
        var segment = updatedSegments[index]
        let previous = index > 0 ? updatedSegments[index - 1] : nil
        let next = index + 1 < updatedSegments.count ? updatedSegments[index + 1] : nil

        switch edge {
        case .left:
            let lowerBound = max(0, (previous?.endMs ?? -minimumGapMs) + minimumGapMs)
            let upperBound = segment.endMs - minimumDurationMs
            segment.startMs = clamp(segment.startMs + deltaMs, lowerBound: lowerBound, upperBound: upperBound, fallback: segment.startMs)
        case .right:
            let lowerBound = segment.startMs + minimumDurationMs
            let durationLimit = durationMs > 0 ? durationMs : Int.max
            let nextLimit = next.map { $0.startMs - minimumGapMs } ?? Int.max
            let upperBound = min(durationLimit, nextLimit)
            segment.endMs = clamp(segment.endMs + deltaMs, lowerBound: lowerBound, upperBound: upperBound, fallback: segment.endMs)
        }

        updatedSegments[index] = segment
        return reindexed(sorted(updatedSegments))
    }

    static func updateSegmentTiming(
        segments: [SubtitleSegment],
        id: UUID,
        startMs: Int,
        endMs: Int,
        durationMs: Int
    ) -> [SubtitleSegment] {
        let sortedSegments = sorted(segments)
        guard let index = sortedSegments.firstIndex(where: { $0.id == id }) else {
            return reindexed(sortedSegments)
        }

        var updatedSegments = sortedSegments
        var segment = updatedSegments[index]
        let previous = index > 0 ? updatedSegments[index - 1] : nil
        let next = index + 1 < updatedSegments.count ? updatedSegments[index + 1] : nil

        let durationLimit = durationMs > 0 ? durationMs : Int.max
        let lowerStartBound = max(0, (previous?.endMs ?? -minimumGapMs) + minimumGapMs)
        let upperEndBound = min(durationLimit, next.map { $0.startMs - minimumGapMs } ?? Int.max)

        let proposedStart = clamp(
            startMs,
            lowerBound: lowerStartBound,
            upperBound: upperEndBound - minimumDurationMs,
            fallback: segment.startMs
        )
        let proposedEnd = clamp(
            endMs,
            lowerBound: proposedStart + minimumDurationMs,
            upperBound: upperEndBound,
            fallback: segment.endMs
        )

        segment.startMs = proposedStart
        segment.endMs = proposedEnd
        updatedSegments[index] = segment
        return reindexed(sorted(updatedSegments))
    }

    static func moveSegment(
        segments: [SubtitleSegment],
        id: UUID,
        deltaMs: Int,
        durationMs: Int
    ) -> [SubtitleSegment] {
        let sortedSegments = sorted(segments)
        guard let index = sortedSegments.firstIndex(where: { $0.id == id }) else {
            return reindexed(sortedSegments)
        }

        var updatedSegments = sortedSegments
        var segment = updatedSegments[index]
        let segmentDuration = max(minimumDurationMs, segment.endMs - segment.startMs)
        let previous = index > 0 ? updatedSegments[index - 1] : nil
        let next = index + 1 < updatedSegments.count ? updatedSegments[index + 1] : nil

        let lowerBound = max(0, (previous?.endMs ?? -minimumGapMs) + minimumGapMs)
        let durationLimit = durationMs > 0 ? durationMs : Int.max
        let nextLimit = next.map { $0.startMs - minimumGapMs } ?? Int.max
        let upperBound = min(durationLimit, nextLimit) - segmentDuration

        let newStart = clamp(segment.startMs + deltaMs, lowerBound: lowerBound, upperBound: upperBound, fallback: segment.startMs)
        segment.startMs = newStart
        segment.endMs = newStart + segmentDuration
        updatedSegments[index] = segment
        return reindexed(sorted(updatedSegments))
    }

    static func reindexed(_ segments: [SubtitleSegment]) -> [SubtitleSegment] {
        sorted(segments).enumerated().map { offset, segment in
            var updatedSegment = segment
            updatedSegment.index = offset + 1
            return updatedSegment
        }
    }

    private static func sorted(_ segments: [SubtitleSegment]) -> [SubtitleSegment] {
        segments.sorted {
            if $0.startMs == $1.startMs {
                return $0.index < $1.index
            }
            return $0.startMs < $1.startMs
        }
    }

    private static func clamp(_ value: Int, lowerBound: Int, upperBound: Int, fallback: Int) -> Int {
        guard lowerBound <= upperBound else {
            return fallback
        }

        return min(max(value, lowerBound), upperBound)
    }
}
