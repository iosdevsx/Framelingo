import Foundation

public enum TranslationStyle: String, Codable, CaseIterable, Identifiable, Equatable {
    case literal
    case natural
    case youtube
    case educational

    public var id: String { rawValue }
}
