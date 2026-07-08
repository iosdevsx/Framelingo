import Foundation

struct TranscriptionInput: Equatable {
    var audioURL: URL?
    var videoURL: URL
    var sourceLanguage: String?
    var progressHandler: TranscriptionProgressHandler?

    static func == (lhs: TranscriptionInput, rhs: TranscriptionInput) -> Bool {
        lhs.audioURL == rhs.audioURL
            && lhs.videoURL == rhs.videoURL
            && lhs.sourceLanguage == rhs.sourceLanguage
    }
}

struct TranscriptionResult: Equatable {
    var segments: [SubtitleSegment]
    var words: [WordTiming]
    var detectedLanguage: String?
    var durationMs: Int?
}

protocol SpeechToTextProvider {
    func transcribe(_ input: TranscriptionInput) async throws -> TranscriptionResult
}

typealias TranscriptionProgressHandler = @Sendable (_ progress: Double?, _ status: String) async -> Void
