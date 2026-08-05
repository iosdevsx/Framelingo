import Foundation

public enum SpeechToTextError: LocalizedError, Equatable, Sendable {
    case audioMissing
    case unsupportedLanguage(String)
    case executableMissing
    case modelMissing
    case transcriptionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .audioMissing:
            "Prepared audio is missing."
        case .unsupportedLanguage(let language):
            "The selected speech-to-text provider does not support \(language)."
        case .executableMissing:
            "The local speech-to-text executable was not found."
        case .modelMissing:
            "The selected speech-to-text model was not found."
        case .transcriptionFailed(let message):
            "Transcription failed: \(message)"
        }
    }
}
