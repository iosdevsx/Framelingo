import Foundation

struct SubtitleSegment: Identifiable, Codable, Equatable {
    let id: UUID
    var index: Int
    var startMs: Int
    var endMs: Int
    var originalText: String
    var translatedText: String
    var speaker: String?
    var speakerId: Int?
    var confidence: Double?
    var warnings: [SubtitleCueWarning]

    var durationMs: Int {
        max(0, endMs - startMs)
    }

    var hasTranslation: Bool {
        !translatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    enum CodingKeys: String, CodingKey {
        case id
        case index
        case startMs
        case endMs
        case originalText
        case translatedText
        case speaker
        case speakerId
        case confidence
        case warnings
    }

    init(
        id: UUID,
        index: Int,
        startMs: Int,
        endMs: Int,
        originalText: String,
        translatedText: String,
        speaker: String? = nil,
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
        self.speaker = speaker
        self.speakerId = speakerId
        self.confidence = confidence
        self.warnings = warnings
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        index = try container.decode(Int.self, forKey: .index)
        startMs = try container.decode(Int.self, forKey: .startMs)
        endMs = try container.decode(Int.self, forKey: .endMs)
        originalText = try container.decode(String.self, forKey: .originalText)
        translatedText = try container.decode(String.self, forKey: .translatedText)
        speaker = try container.decodeIfPresent(String.self, forKey: .speaker)
        speakerId = try container.decodeIfPresent(Int.self, forKey: .speakerId)
        confidence = try container.decodeIfPresent(Double.self, forKey: .confidence)
        warnings = try container.decodeIfPresent([SubtitleCueWarning].self, forKey: .warnings) ?? []
    }
}
