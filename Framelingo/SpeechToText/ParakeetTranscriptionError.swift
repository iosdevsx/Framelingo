import Foundation

enum ParakeetTranscriptionError: LocalizedError, Equatable {
    case audioMissing
    case requiresMacOS14
    case modelLoadFailed(String)
    case unsupportedLanguage(String)
    case transcriptionFailed(String)

    var errorDescription: String? {
        switch self {
        case .audioMissing:
            return "Extracted audio file is missing."
        case .requiresMacOS14:
            return "Parakeet transcription requires macOS 14 or later."
        case .modelLoadFailed(let message):
            return "Parakeet models could not be loaded: \(message)"
        case .unsupportedLanguage(let language):
            return "Parakeet does not support \(language). Install Local Whisper, choose a supported source language, or switch speech-to-text providers."
        case .transcriptionFailed(let message):
            let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Parakeet transcription failed." : "Parakeet transcription failed: \(trimmed)"
        }
    }
}
