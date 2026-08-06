public protocol TranslationOrchestrating {
    func translateSubtitles(_ input: SubtitleTranslationInput) async throws -> SubtitleTranslationResult
}
