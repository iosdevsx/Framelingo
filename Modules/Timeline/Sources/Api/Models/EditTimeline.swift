import Foundation

public struct EditTimeline: Codable, Equatable {
    public var clips: [TimelineClip]
    public var totalDurationMs: Int

    public init(clips: [TimelineClip], totalDurationMs: Int) {
        self.clips = clips
        self.totalDurationMs = totalDurationMs
    }

    public var isEmpty: Bool {
        clips.isEmpty || totalDurationMs <= 0
    }

    public var hasVirtualCuts: Bool {
        guard clips.count == 1, let clip = clips.first else {
            return !clips.isEmpty
        }

        return clip.sourceStartMs != 0
            || clip.timelineStartMs != 0
            || clip.sourceDurationMs != clip.timelineDurationMs
    }
}
