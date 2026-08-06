public protocol ParakeetModelManaging {
    var approximateDownloadSizeText: String { get }
    func modelsArePresent() -> Bool
    func installModels(
        progressHandler: @escaping @Sendable (SpeechModelDownloadProgress) async -> Void
    ) async throws
}
