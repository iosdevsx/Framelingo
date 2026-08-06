import Foundation

public struct WordTiming: Identifiable, Codable, Hashable {
    public let id: UUID
    public var text: String
    public var start: TimeInterval
    public var end: TimeInterval
    public var confidence: Double?

    public init(
        id: UUID = UUID(),
        text: String,
        start: TimeInterval,
        end: TimeInterval,
        confidence: Double? = nil
    ) {
        self.id = id
        self.text = text
        self.start = start
        self.end = end
        self.confidence = confidence
    }
}
