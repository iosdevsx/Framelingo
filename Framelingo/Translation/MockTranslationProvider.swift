import Foundation

struct MockTranslationProvider: TranslationProvider {
    func translateSubtitles(_ input: SubtitleTranslationInput) async throws -> SubtitleTranslationResult {
        try await Task.sleep(for: .milliseconds(300))

        let translatedSegments = input.segments.map { segment in
            var translatedSegment = segment
            translatedSegment.translatedText = mockTranslation(
                for: segment.originalText,
                targetLanguage: input.targetLanguage,
                style: input.style
            )
            return translatedSegment
        }

        return SubtitleTranslationResult(segments: translatedSegments)
    }

    private func mockTranslation(
        for text: String,
        targetLanguage: String,
        style: TranslationStyle
    ) -> String {
        let prefix = prefix(for: targetLanguage)
        let styleLabel = label(for: style)
        return "\(prefix) \(styleLabel): \(text)"
    }

    private func prefix(for language: String) -> String {
        switch language.lowercased() {
        case let value where value.contains("russian"):
            return "Перевод"
        case let value where value.contains("spanish"):
            return "Traducción"
        case let value where value.contains("french"):
            return "Traduction"
        case let value where value.contains("german"):
            return "Übersetzung"
        case let value where value.contains("italian"):
            return "Traduzione"
        case let value where value.contains("portuguese"):
            return "Tradução"
        case let value where value.contains("chinese"):
            return "翻译"
        case let value where value.contains("japanese"):
            return "翻訳"
        case let value where value.contains("korean"):
            return "번역"
        default:
            return "Translation"
        }
    }

    private func label(for style: TranslationStyle) -> String {
        switch style {
        case .literal:
            return "literal"
        case .natural:
            return "natural"
        case .youtube:
            return "youtube"
        case .educational:
            return "educational"
        }
    }
}
