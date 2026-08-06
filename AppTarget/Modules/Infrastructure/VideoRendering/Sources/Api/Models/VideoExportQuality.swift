import Foundation

public enum VideoExportQuality: String, Codable, CaseIterable, Identifiable, Sendable {
    case smallFile
    case normal
    case high

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .smallFile: "Small file"
        case .normal: "Normal"
        case .high: "High"
        }
    }

    public var crf: Int {
        switch self {
        case .smallFile: 28
        case .normal: 23
        case .high: 18
        }
    }

    public var mpeg4QualityScale: Int {
        switch self {
        case .smallFile: 8
        case .normal: 5
        case .high: 2
        }
    }
}
