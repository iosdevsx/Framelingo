import Foundation

public enum ExportFormat: String, CaseIterable, Codable, Identifiable {
    case srt
    case vtt
    case txt

    public var id: String { rawValue }

    public var displayName: String {
        rawValue.uppercased()
    }
}
