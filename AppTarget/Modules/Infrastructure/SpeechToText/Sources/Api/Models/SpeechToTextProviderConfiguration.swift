import Foundation

public struct SpeechToTextProviderConfiguration: Equatable {
    public var providerName: String
    public var whisperExecutableURL: URL?
    public var whisperModelURL: URL?
    public var whisperModelName: String
    public var whisperVADEnabled: Bool
    public var whisperVADModelURL: URL?

    public init(
        providerName: String,
        whisperExecutableURL: URL? = nil,
        whisperModelURL: URL? = nil,
        whisperModelName: String = WhisperModel.base.rawValue,
        whisperVADEnabled: Bool = false,
        whisperVADModelURL: URL? = nil
    ) {
        self.providerName = providerName
        self.whisperExecutableURL = whisperExecutableURL
        self.whisperModelURL = whisperModelURL
        self.whisperModelName = whisperModelName
        self.whisperVADEnabled = whisperVADEnabled
        self.whisperVADModelURL = whisperVADModelURL
    }
}
