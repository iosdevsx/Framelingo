import Foundation

/// A discrete crop position change in short-local time. Export and preview
/// hold the previous crop until the next point; no movement is animated.
public struct ShortCropKeyframe: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var timeMs: Int
    public var offsetX: Double

    public init(id: UUID = UUID(), timeMs: Int, offsetX: Double) {
        self.id = id
        self.timeMs = max(0, timeMs)
        self.offsetX = min(max(offsetX, 0), 1)
    }
}
