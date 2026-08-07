import Translation

public enum TranslationAssembly {
    public static func makeMockProvider() -> TranslationProvider {
        MockTranslationProvider()
    }

    public static func makeService(
        provider: TranslationProvider
    ) -> TranslationOrchestrating {
        TranslationService(provider: provider)
    }

    public static func makeMockService() -> TranslationOrchestrating {
        TranslationService(provider: MockTranslationProvider())
    }
}
