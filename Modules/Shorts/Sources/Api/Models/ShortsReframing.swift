import Foundation

public enum ShortsReframing: String, Codable, CaseIterable, Identifiable {
    case blurPad
    case crop

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .blurPad:
            return "Blurred background"
        case .crop:
            return "Crop"
        }
    }
}
