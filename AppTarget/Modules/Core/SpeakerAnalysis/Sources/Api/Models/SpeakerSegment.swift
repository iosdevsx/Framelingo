import Foundation

public struct SpeakerSegment: Identifiable, Codable, Hashable {
    public let id: UUID
    public var speakerId: Int
    public var start: TimeInterval
    public var end: TimeInterval
    public var confidence: Double?

    public init(
        id: UUID = UUID(),
        speakerId: Int,
        start: TimeInterval,
        end: TimeInterval,
        confidence: Double? = nil
    ) {
        self.id = id
        self.speakerId = speakerId
        self.start = start
        self.end = end
        self.confidence = confidence
    }
}
