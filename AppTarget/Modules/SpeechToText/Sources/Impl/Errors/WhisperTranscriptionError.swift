import Foundation

enum WhisperTranscriptionError: LocalizedError, Equatable {
    case audioMissing
    case outputMissing
    case executableMissing
    case modelMissing
    case launchFailed(String)
    case processFailed(String)

    var errorDescription: String? {
        switch self {
        case .audioMissing:
            return "Extracted audio file is missing."
        case .outputMissing:
            return "Whisper did not create a transcript file."
        case .executableMissing:
            return "Whisper is not installed. Open Settings and install Local Whisper."
        case .modelMissing:
            return "Whisper model is missing. Open Settings and install Local Whisper."
        case .launchFailed(let description):
            return "Could not launch Whisper: \(description)"
        case .processFailed(let stderr):
            let trimmed = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Whisper transcription failed." : "Whisper transcription failed: \(trimmed)"
        }
    }
}
