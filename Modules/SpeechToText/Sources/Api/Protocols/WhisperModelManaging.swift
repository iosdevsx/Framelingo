public protocol WhisperModelManaging {
    func install(
        model: WhisperModel,
        progressHandler: @escaping @Sendable (WhisperInstallStage, Double?) async -> Void
    ) async throws -> WhisperInstallation
}
