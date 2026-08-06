import Foundation

public struct TimelineClip: Identifiable, Codable, Equatable {
    public var id: UUID
    public var sourceStartMs: Int
    public var sourceEndMs: Int
    public var timelineStartMs: Int
    public var timelineEndMs: Int

    public init(
        id: UUID,
        sourceStartMs: Int,
        sourceEndMs: Int,
        timelineStartMs: Int,
        timelineEndMs: Int
    ) {
        self.id = id
        self.sourceStartMs = sourceStartMs
        self.sourceEndMs = sourceEndMs
        self.timelineStartMs = timelineStartMs
        self.timelineEndMs = timelineEndMs
    }

    public var sourceDurationMs: Int {
        max(0, sourceEndMs - sourceStartMs)
    }

    public var timelineDurationMs: Int {
        max(0, timelineEndMs - timelineStartMs)
    }
}
