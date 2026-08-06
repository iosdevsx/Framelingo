public protocol SpeechToTextProvider {
    func transcribe(_ input: TranscriptionInput) async throws -> TranscriptionResult
}
