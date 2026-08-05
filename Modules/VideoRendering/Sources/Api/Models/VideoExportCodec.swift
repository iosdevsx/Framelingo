import Foundation

public enum VideoExportCodec: String, Codable, CaseIterable, Identifiable, Sendable {
    case h264

    public var id: String { rawValue }
    public var displayName: String { "H.264" }
}
