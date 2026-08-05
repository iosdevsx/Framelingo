import Foundation

public enum SubtitleLayoutMode: String, CaseIterable, Identifiable {
    case split
    case videoFocus
    case transcript

    public var id: String { rawValue }
}
