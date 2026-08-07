import Foundation

public struct VideoCropKeyframe: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var timeMs: Int
    public var offsetX: Double

    public init(id: UUID, timeMs: Int, offsetX: Double) {
        self.id = id
        self.timeMs = timeMs
        self.offsetX = offsetX
    }
}
