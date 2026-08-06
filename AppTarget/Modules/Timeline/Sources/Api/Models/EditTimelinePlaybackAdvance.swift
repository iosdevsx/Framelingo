public enum EditTimelinePlaybackAdvance: Equatable {
    case paused
    case finished(totalDurationMs: Int)
    case seekWithinClip(timelineMs: Int)
    case advanceToNextClip(TimelineClip)
}
