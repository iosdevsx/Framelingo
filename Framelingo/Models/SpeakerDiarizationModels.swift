import Foundation

struct WordTiming: Identifiable, Codable, Hashable {
    let id: UUID
    var text: String
    var start: TimeInterval
    var end: TimeInterval
    var confidence: Double?

    init(
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

struct SpeakerSegment: Identifiable, Codable, Hashable {
    let id: UUID
    var speakerId: Int
    var start: TimeInterval
    var end: TimeInterval
    var confidence: Double?

    init(
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

struct SpeakerLabel: Identifiable, Codable, Hashable {
    let id: Int
    var displayName: String

    init(id: Int, displayName: String) {
        self.id = id
        self.displayName = displayName
    }
}

enum SubtitleCueWarning: String, Codable, Hashable {
    case overlappingSpeakers
    case lowConfidenceSpeaker
    case tooLong
    case tooShort
    case noSpeakerDetected
}

struct SubtitleAlignmentOptions: Codable, Hashable {
    var maxCueDuration: TimeInterval
    var minCueDuration: TimeInterval
    var maxCharsPerCue: Int
    var maxCharsPerLine: Int
    var pauseSplitThreshold: TimeInterval
    var startPadding: TimeInterval
    var endPadding: TimeInterval
    var lowConfidenceThreshold: Double
    var minWordsPerSpeakerRun: Int

    init(
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

    enum CodingKeys: String, CodingKey {
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

    init(from decoder: Decoder) throws {
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
