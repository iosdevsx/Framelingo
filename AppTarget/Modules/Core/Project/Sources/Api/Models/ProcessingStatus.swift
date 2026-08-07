import Foundation

public enum ProcessingStatus: Codable, Equatable {
    case idle
    case extractingAudio
    case transcribing
    case translating
    case exporting
    case ready
    case failed(String)
}

public extension ProcessingStatus {
    var displayName: String {
        switch self {
        case .idle:
            "Idle"
        case .extractingAudio:
            "Extracting audio"
        case .transcribing:
            "Transcribing"
        case .translating:
            "Translating"
        case .exporting:
            "Exporting"
        case .ready:
            "Ready"
        case .failed(let message):
            "Failed: \(message)"
        }
    }
}
