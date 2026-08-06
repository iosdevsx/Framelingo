import Foundation

enum DiarizationModelError: LocalizedError, Equatable {
    case modelsNotFound
    case modelDirectoryUnavailable
    case modelLoadFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelsNotFound:
            "Speaker analysis models are not installed yet."
        case .modelDirectoryUnavailable:
            "Speaker analysis model directory is unavailable."
        case .modelLoadFailed(let message):
            "Speaker analysis models could not be loaded: \(message)"
        }
    }
}
