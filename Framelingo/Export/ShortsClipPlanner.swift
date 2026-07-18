import Foundation

/// Resolves a short's timeline-time range into source clip ranges for the
/// clip-aware FFmpeg export path, and re-times subtitles into the short's
/// local timeline.
enum ShortsClipPlanner {
    /// Intersects the short's range with the edit timeline's clips. Without an
    /// edit timeline, timeline time equals source time and the short maps to a
    /// single source range. Throws `ExportClipPlanError.emptyPlan` when the
    /// intersection is empty or the range is degenerate.
    static func clips(
        for short: ShortDefinition,
        editTimeline: EditTimeline?
    ) throws -> [ExportClipRange] {
        guard short.durationMs > 0 else {
            throw ExportClipPlanError.emptyPlan
        }

        guard let editTimeline, !editTimeline.clips.isEmpty else {
            return [ExportClipRange(sourceStartMs: short.startMs, sourceEndMs: short.endMs)]
        }

        let clips = editTimeline.clips
            .sorted { $0.timelineStartMs < $1.timelineStartMs }
            .compactMap { clip -> ExportClipRange? in
                let overlapStart = max(short.startMs, clip.timelineStartMs)
                let overlapEnd = min(short.endMs, clip.timelineEndMs)
                guard overlapEnd > overlapStart else {
                    return nil
                }

                let sourceStart = clip.sourceStartMs + (overlapStart - clip.timelineStartMs)
                return ExportClipRange(
                    sourceStartMs: sourceStart,
                    sourceEndMs: sourceStart + (overlapEnd - overlapStart)
                )
            }
            .filter { $0.durationMs > 0 }

        guard !clips.isEmpty else {
            throw ExportClipPlanError.emptyPlan
        }

        return clips
    }

    /// Cues overlapping the short's range, clamped to its boundaries and
    /// shifted into the short's local timeline (starting at 0), reindexed.
    static func localizedSubtitles(
        _ segments: [SubtitleSegment],
        for short: ShortDefinition
    ) -> [SubtitleSegment] {
        segments
            .filter { $0.endMs > short.startMs && $0.startMs < short.endMs }
            .sorted { $0.startMs < $1.startMs }
            .enumerated()
            .map { offset, segment in
                var localized = segment
                localized.index = offset + 1
                localized.startMs = max(segment.startMs, short.startMs) - short.startMs
                localized.endMs = min(segment.endMs, short.endMs) - short.startMs
                return localized
            }
            .filter { $0.endMs > $0.startMs }
    }
}
