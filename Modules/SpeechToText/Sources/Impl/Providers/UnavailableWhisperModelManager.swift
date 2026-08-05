import SpeechToText

#if !os(macOS)
struct UnavailableWhisperModelManager: WhisperModelManaging {
    func install(
        model: WhisperModel,
        progressHandler: @escaping @Sendable (WhisperInstallStage, Double?) async -> Void
    ) async throws -> WhisperInstallation {
        throw SpeechToTextError.executableMissing
    }
}
#endif
