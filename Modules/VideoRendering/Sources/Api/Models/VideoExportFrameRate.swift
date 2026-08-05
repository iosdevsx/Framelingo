import Foundation

public enum VideoExportFrameRate: String, Codable, CaseIterable, Identifiable, Sendable {
    case original
    case fps24
    case fps25
    case fps30
    case fps50
    case fps60

    public var id: String { rawValue }

    public var displayName: String {
        guard let framesPerSecond else { return "Original" }
        return "\(framesPerSecond) fps"
    }

    public var framesPerSecond: Int? {
        switch self {
        case .original: nil
        case .fps24: 24
        case .fps25: 25
        case .fps30: 30
        case .fps50: 50
        case .fps60: 60
        }
    }
}
