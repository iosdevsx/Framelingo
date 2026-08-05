import Foundation

public struct WhisperInstallation: Equatable {
    public var executableURL: URL
    public var modelURL: URL
    public var model: WhisperModel
    /// nil when the VAD model download failed; transcription stays usable without VAD.
    public var vadModelURL: URL?
    public var vadModelErrorMessage: String?

    public init(
        executableURL: URL,
        modelURL: URL,
        model: WhisperModel,
        vadModelURL: URL?,
        vadModelErrorMessage: String?
    ) {
        self.executableURL = executableURL
        self.modelURL = modelURL
        self.model = model
        self.vadModelURL = vadModelURL
        self.vadModelErrorMessage = vadModelErrorMessage
    }
}
