import Foundation

public struct SubtitleAlignmentOptions: Codable, Hashable {
    public var maxCueDuration: TimeInterval
    public var minCueDuration: TimeInterval
    public var maxCharsPerCue: Int
    public var maxCharsPerLine: Int
    public var pauseSplitThreshold: TimeInterval
    public var startPadding: TimeInterval
    public var endPadding: TimeInterval
    public var lowConfidenceThreshold: Double
    public var minWordsPerSpeakerRun: Int

    public init(
        maxCueDuration: TimeInterval = 6.0,
        minCueDuration: TimeInterval = 0.8,
        maxCharsPerCue: Int = 84,
        maxCharsPerLine: Int = 42,
        pauseSplitThreshold: TimeInterval = 0.7,
        startPadding: TimeInterval = 0.05,
        endPadding: TimeInterval = 0.10,
        lowConfidenceThreshold: Double = 0.55,
        minWordsPerSpeakerRun: Int = 2
    ) {
        self.maxCueDuration = maxCueDuration
        self.minCueDuration = minCueDuration
        self.maxCharsPerCue = maxCharsPerCue
        self.maxCharsPerLine = maxCharsPerLine
        self.pauseSplitThreshold = pauseSplitThreshold
        self.startPadding = startPadding
        self.endPadding = endPadding
        self.lowConfidenceThreshold = lowConfidenceThreshold
        self.minWordsPerSpeakerRun = minWordsPerSpeakerRun
    }

    public enum CodingKeys: String, CodingKey {
        case maxCueDuration
        case minCueDuration
        case maxCharsPerCue
        case maxCharsPerLine
        case pauseSplitThreshold
        case startPadding
        case endPadding
        case lowConfidenceThreshold
        case minWordsPerSpeakerRun
    }

    public init(from decoder: Decoder) throws {
        let defaults = Self()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        maxCueDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .maxCueDuration) ?? defaults.maxCueDuration
        minCueDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .minCueDuration) ?? defaults.minCueDuration
        maxCharsPerCue = try container.decodeIfPresent(Int.self, forKey: .maxCharsPerCue) ?? defaults.maxCharsPerCue
        maxCharsPerLine = try container.decodeIfPresent(Int.self, forKey: .maxCharsPerLine) ?? defaults.maxCharsPerLine
        pauseSplitThreshold = try container.decodeIfPresent(TimeInterval.self, forKey: .pauseSplitThreshold) ?? defaults.pauseSplitThreshold
        startPadding = try container.decodeIfPresent(TimeInterval.self, forKey: .startPadding) ?? defaults.startPadding
        endPadding = try container.decodeIfPresent(TimeInterval.self, forKey: .endPadding) ?? defaults.endPadding
        lowConfidenceThreshold = try container.decodeIfPresent(Double.self, forKey: .lowConfidenceThreshold) ?? defaults.lowConfidenceThreshold
        minWordsPerSpeakerRun = try container.decodeIfPresent(Int.self, forKey: .minWordsPerSpeakerRun) ?? defaults.minWordsPerSpeakerRun
    }
}
