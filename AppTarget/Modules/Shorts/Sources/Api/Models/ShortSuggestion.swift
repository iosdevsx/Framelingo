import Foundation

public struct ShortSuggestion: Identifiable, Equatable {
    public let id: UUID
    public var startMs: Int
    public var endMs: Int
    public var reason: ShortSuggestionReason

    public var durationMs: Int {
        max(0, endMs - startMs)
    }

    public init(id: UUID = UUID(), startMs: Int, endMs: Int, reason: ShortSuggestionReason) {
        self.id = id
        self.startMs = startMs
        self.endMs = endMs
        self.reason = reason
    }
}
