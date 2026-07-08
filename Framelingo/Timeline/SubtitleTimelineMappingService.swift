import Foundation

struct SubtitleTimelineMappingService {
    func rippleDeleteSubtitles(
        segments: [SubtitleSegment],
        range: VideoCutRange,
        minimumSegmentDurationMs: Int = 500
    ) -> [SubtitleSegment] {
        let normalizedRange = range.normalized
        let cutStart = normalizedRange.startMs
        let cutEnd = normalizedRange.endMs
        let cutDuration = normalizedRange.durationMs

        guard cutDuration > 0 else {
            return SubtitleTimingValidator.reindexed(segments)
        }

        let updatedSegments = segments.compactMap { segment -> SubtitleSegment? in
            var updated = segment

            if updated.endMs <= cutStart {
                return updated
            }

            if updated.startMs >= cutEnd {
                updated.startMs -= cutDuration
                updated.endMs -= cutDuration
                return updated
            }

            if updated.startMs < cutStart && updated.endMs > cutEnd {
                updated.endMs -= cutDuration
                return updated.durationMs >= minimumSegmentDurationMs ? updated : nil
            }

            if updated.startMs < cutStart && updated.endMs > cutStart {
                updated.endMs = cutStart
                return updated.durationMs >= minimumSegmentDurationMs ? updated : nil
            }

            if updated.startMs < cutEnd && updated.endMs > cutEnd {
                updated.startMs = cutStart
                updated.endMs -= cutDuration
                return updated.durationMs >= minimumSegmentDurationMs ? updated : nil
            }

            return nil
        }

        return SubtitleTimingValidator.reindexed(
            updatedSegments
                .filter { $0.startMs >= 0 && $0.endMs > $0.startMs }
                .sorted { $0.startMs < $1.startMs }
        )
    }
}
