import Foundation

public enum SubtitleTimecodeError: LocalizedError, Equatable {
    case invalidTimestamp(String)
    case invalidSRTBlock(String)

    public var errorDescription: String? {
        switch self {
        case .invalidTimestamp(let value):
            "Invalid SRT timestamp: \(value)"
        case .invalidSRTBlock(let value):
            "Invalid SRT block: \(value)"
        }
    }
}
