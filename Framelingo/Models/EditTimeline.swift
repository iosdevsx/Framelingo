import Foundation

struct EditTimeline: Codable, Equatable {
    var clips: [TimelineClip]
    var totalDurationMs: Int

    var isEmpty: Bool {
        clips.isEmpty || totalDurationMs <= 0
    }

    var hasVirtualCuts: Bool {
        guard clips.count == 1, let clip = clips.first else {
            return !clips.isEmpty
        }

        return clip.sourceStartMs != 0
            || clip.timelineStartMs != 0
            || clip.sourceDurationMs != clip.timelineDurationMs
    }
}

struct TimelineClip: Identifiable, Codable, Equatable {
    var id: UUID
    var sourceStartMs: Int
    var sourceEndMs: Int
    var timelineStartMs: Int
    var timelineEndMs: Int

    var sourceDurationMs: Int {
        max(0, sourceEndMs - sourceStartMs)
    }

    var timelineDurationMs: Int {
        max(0, timelineEndMs - timelineStartMs)
    }
}

struct VideoCutRange: Equatable {
    var startMs: Int
    var endMs: Int

    var normalized: VideoCutRange {
        VideoCutRange(startMs: min(startMs, endMs), endMs: max(startMs, endMs))
    }

    var durationMs: Int {
        max(0, endMs - startMs)
    }
}
