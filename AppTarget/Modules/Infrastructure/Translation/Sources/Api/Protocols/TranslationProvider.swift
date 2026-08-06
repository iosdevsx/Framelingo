public protocol TranslationProvider {
    func translateSubtitles(_ input: SubtitleTranslationInput) async throws -> SubtitleTranslationResult
}
