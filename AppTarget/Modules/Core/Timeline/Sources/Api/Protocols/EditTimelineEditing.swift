import Foundation

public protocol EditTimelineEditing {
    func makeInitialTimeline(durationMs: Int) -> EditTimeline

    func rippleDeleteRange(
        timeline: EditTimeline,
        range: VideoCutRange
    ) throws -> EditTimeline

    func splitAt(timeline: EditTimeline, timelineMs: Int) throws -> EditTimeline
    func deleteClip(timeline: EditTimeline, clipID: UUID) throws -> EditTimeline
    func sourceTime(forTimelineTime timelineMs: Int, in timeline: EditTimeline) -> Int?
    func clip(atTimelineTime timelineMs: Int, in timeline: EditTimeline) -> TimelineClip?

    func playbackAdvance(
        sourceTimeMs: Int,
        currentClipID: UUID?,
        lastKnownTimelineMs: Int,
        in timeline: EditTimeline,
        lookaheadMs: Int
    ) -> EditTimelinePlaybackAdvance

    func recalculateTimelinePositions(clips: [TimelineClip]) -> EditTimeline
}

public extension EditTimelineEditing {
    func playbackAdvance(
        sourceTimeMs: Int,
        currentClipID: UUID?,
        lastKnownTimelineMs: Int,
        in timeline: EditTimeline
    ) -> EditTimelinePlaybackAdvance {
        playbackAdvance(
            sourceTimeMs: sourceTimeMs,
            currentClipID: currentClipID,
            lastKnownTimelineMs: lastKnownTimelineMs,
            in: timeline,
            lookaheadMs: 30
        )
    }
}
