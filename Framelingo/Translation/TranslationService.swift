import Foundation

final class TranslationService {
    private let provider: TranslationProvider

    init(provider: TranslationProvider) {
        self.provider = provider
    }

    func translateSubtitles(_ input: SubtitleTranslationInput) async throws -> SubtitleTranslationResult {
        try await provider.translateSubtitles(input)
    }
}
