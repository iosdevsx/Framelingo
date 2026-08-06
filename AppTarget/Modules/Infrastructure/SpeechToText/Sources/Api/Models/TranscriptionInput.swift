import Foundation

public struct TranscriptionInput: Equatable {
    public var audioURL: URL?
    public var videoURL: URL
    public var sourceLanguage: String?
    public var progressHandler: TranscriptionProgressHandler?

    public init(
        audioURL: URL?,
        videoURL: URL,
        sourceLanguage: String?,
        progressHandler: TranscriptionProgressHandler? = nil
    ) {
        self.audioURL = audioURL
        self.videoURL = videoURL
        self.sourceLanguage = sourceLanguage
        self.progressHandler = progressHandler
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.audioURL == rhs.audioURL
            && lhs.videoURL == rhs.videoURL
            && lhs.sourceLanguage == rhs.sourceLanguage
    }
}
