import Foundation

#if os(macOS)
enum WhisperInstallerError: LocalizedError {
    case executableNotFound
    case modelDownloadFailed
    case invalidModel

    var errorDescription: String? {
        switch self {
        case .executableNotFound:
            return "Whisper executable was not found. Add whisper.cpp to the project or bundle whisper-cli with the app."
        case .modelDownloadFailed:
            return "Could not download the Whisper model."
        case .invalidModel:
            return "Selected Whisper model is invalid."
        }
    }
}
#endif
