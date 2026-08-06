import Foundation

public enum VideoExportResolution: String, Codable, CaseIterable, Identifiable, Sendable {
    case original
    case p2160
    case p1440
    case p1080
    case p720

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .original: "Original"
        case .p2160: "2160p"
        case .p1440: "1440p"
        case .p1080: "1080p"
        case .p720: "720p"
        }
    }

    public var shortSideTarget: Int? {
        switch self {
        case .original: nil
        case .p2160: 2_160
        case .p1440: 1_440
        case .p1080: 1_080
        case .p720: 720
        }
    }
}
