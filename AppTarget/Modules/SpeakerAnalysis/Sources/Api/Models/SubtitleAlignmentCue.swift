import Foundation

/// A transient alignment projection. Application maps it to the single
/// session-owned SubtitleSegment array; it is never persisted separately.
public struct SubtitleAlignmentCue: Identifiable, Equatable {
    public let id: UUID
    public var index: Int
    public var startMs: Int
    public var endMs: Int
    public var originalText: String
    public var translatedText: String
    public var speakerId: Int?
    public var confidence: Double?
    public var warnings: [SubtitleCueWarning]

    public init(
        id: UUID,
        index: Int,
        startMs: Int,
        endMs: Int,
        originalText: String,
        translatedText: String,
        speakerId: Int? = nil,
        confidence: Double? = nil,
        warnings: [SubtitleCueWarning] = []
    ) {
        self.id = id
        self.index = index
        self.startMs = startMs
        self.endMs = endMs
        self.originalText = originalText
        self.translatedText = translatedText
        self.speakerId = speakerId
        self.confidence = confidence
        self.warnings = warnings
    }
}
