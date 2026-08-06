import Foundation

public enum EditorDensity: String, CaseIterable, Identifiable {
    case compact
    case comfy

    public var id: String { rawValue }
}
