import Foundation

enum TranslationStyle: String, Codable, CaseIterable, Identifiable, Equatable {
    case literal
    case natural
    case youtube
    case educational

    var id: String { rawValue }
}

struct SubtitleTranslationInput: Equatable {
    var segments: [SubtitleSegment]
    var sourceLanguage: String
    var targetLanguage: String
    var style: TranslationStyle
}

struct SubtitleTranslationResult: Equatable {
    var segments: [SubtitleSegment]
}

protocol TranslationProvider {
    func translateSubtitles(_ input: SubtitleTranslationInput) async throws -> SubtitleTranslationResult
}
