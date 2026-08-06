import Foundation
import Subtitles
import Testing
import Translation
import TranslationImpl

@Suite("Translation implementation")
struct TranslationImplTests {
    @Test("Mock orchestration preserves cues and writes translated text")
    func mockTranslation() async throws {
        let segment = SubtitleSegment(
            id: UUID(),
            index: 1,
            startMs: 100,
            endMs: 900,
            originalText: "Hello",
            translatedText: ""
        )
        let input = SubtitleTranslationInput(
            segments: [segment],
            sourceLanguage: "English",
            targetLanguage: "Russian",
            style: .natural
        )

        let result = try await TranslationAssembly
            .makeMockService()
            .translateSubtitles(input)

        #expect(result.segments.count == 1)
        #expect(result.segments[0].id == segment.id)
        #expect(result.segments[0].startMs == segment.startMs)
        #expect(result.segments[0].translatedText == "Перевод natural: Hello")
    }

    @Test("Assembly exposes API protocols")
    func apiTypedAssembly() {
        let provider: TranslationProvider = TranslationAssembly.makeMockProvider()
        let service: TranslationOrchestrating = TranslationAssembly
            .makeService(provider: provider)

        _ = service
    }
}
