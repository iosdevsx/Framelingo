import SpeechToText

struct StubSpeechToTextProvider: SpeechToTextProvider {
    var result: TranscriptionResult

    func transcribe(_ input: TranscriptionInput) async throws -> TranscriptionResult {
        result
    }
}
