import Foundation

enum DiarizationError: LocalizedError, Equatable {
    case requiresMacOS14
    case modelLoadFailed(String)

    var errorDescription: String? {
        switch self {
        case .requiresMacOS14:
            "Speaker analysis requires macOS 14 or later."
        case .modelLoadFailed(let message):
            "Speaker analysis failed to load models: \(message)"
        }
    }
}
