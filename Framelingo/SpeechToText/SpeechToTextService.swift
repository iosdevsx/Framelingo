import Foundation

final class SpeechToTextService {
    private let provider: SpeechToTextProvider

    init(provider: SpeechToTextProvider) {
        self.provider = provider
    }

    func transcribe(_ input: TranscriptionInput) async throws -> TranscriptionResult {
        try await provider.transcribe(input)
    }
}
